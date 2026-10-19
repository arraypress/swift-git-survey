//
//  Spawn.swift
//  GitSurvey
//
//  Created by David Sherlock on 2026.
//
//  Running git and gh as child processes, hundreds at a time, without a
//  shell and without anything able to wait on a person.
//
//  Each child starts in a session of its own (POSIX_SPAWN_SETSID), so it has
//  no controlling terminal: ssh asking about a host key or a passphrase, or
//  git asking for a password, fails at once instead of writing to the
//  terminal `repos` runs in and waiting there. The session is also a process
//  group, so a timeout stops git together with the ssh it started. stdin is
//  /dev/null; every descriptor but the three is closed in the child
//  (POSIX_SPAWN_CLOEXEC_DEFAULT), so children started side by side never
//  inherit each other's pipes and every pipe ends when its child does. Both
//  pipes are read as data arrives, so a full pipe can never stall a child.
//

import Darwin
import Foundation

/// What a child process did.
struct ChildResult: Sendable, Equatable {

    /// Its exit status; 128 + the signal when a signal ended it.
    let status: Int32

    /// Everything it wrote to stdout.
    let stdout: Data

    /// Everything it wrote to stderr.
    let stderr: Data

    /// Whether it was stopped for running past its timeout.
    let timedOut: Bool

    /// Exited 0 within its time.
    var succeeded: Bool { status == 0 && !timedOut }

    /// stdout as UTF-8 (lossy).
    var output: String { String(decoding: stdout, as: UTF8.self) }

    /// The last non-empty line of stderr — what git says went wrong.
    var reason: String {
        let lines = String(decoding: stderr, as: UTF8.self).split(whereSeparator: \.isNewline)
        return lines.last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
    }
}

enum Spawn {

    /// Seconds between SIGTERM and SIGKILL, and again before the pipes are abandoned.
    static let grace: Double = 2

    /// Runs `executable` with `arguments` and `environment` (the whole of it),
    /// stopping its process group after `timeout` seconds.
    ///
    /// - Throws: ``GitSurveyError/toolFailed(tool:reason:)`` when it cannot be started.
    static func run(_ executable: String, _ arguments: [String], environment: [String: String],
                    timeout: Double) async throws -> ChildResult {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try start(executable, arguments, environment: environment, timeout: timeout) {
                    continuation.resume(returning: $0)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func start(_ executable: String, _ arguments: [String], environment: [String: String],
                              timeout: Double, completion: @escaping @Sendable (ChildResult) -> Void) throws {
        let tool = (executable as NSString).lastPathComponent
        var outPipe: [Int32] = [0, 0], errPipe: [Int32] = [0, 0]
        guard pipe(&outPipe) == 0 else { throw GitSurveyError.toolFailed(tool: tool, reason: String(cString: strerror(errno))) }
        guard pipe(&errPipe) == 0 else {
            close(outPipe[0]); close(outPipe[1])
            throw GitSurveyError.toolFailed(tool: tool, reason: String(cString: strerror(errno)))
        }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, outPipe[1], 1)
        posix_spawn_file_actions_adddup2(&actions, errPipe[1], 2)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        let flags = POSIX_SPAWN_SETSID | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK
        posix_spawnattr_setflags(&attributes, Int16(flags))
        // The parent ignores SIGPIPE (CLIKit does); a child must not inherit that.
        var all = sigset_t(), none = sigset_t()
        sigfillset(&all)
        sigemptyset(&none)
        posix_spawnattr_setsigdefault(&attributes, &all)
        posix_spawnattr_setsigmask(&attributes, &none)

        let argv = ([executable] + arguments).map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            argv.forEach { free($0) }
            envp.forEach { free($0) }
        }

        var pid: pid_t = 0
        let spawned = posix_spawn(&pid, executable, &actions, &attributes, argv, envp)
        close(outPipe[1])
        close(errPipe[1])
        guard spawned == 0 else {
            close(outPipe[0]); close(errPipe[0])
            throw GitSurveyError.toolFailed(tool: tool, reason: String(cString: strerror(spawned)))
        }

        let run = ChildRun(pid: pid, stdout: outPipe[0], stderr: errPipe[0], completion: completion)
        run.begin(timeout: timeout)
    }
}

/// One running child: its two pipes, its timeout, and the single completion.
private final class ChildRun: @unchecked Sendable {

    private let lock = NSLock()
    private let pid: pid_t
    private var handles: [FileHandle?]
    private var buffers = [Data(), Data()]
    private var open = 2
    private var timedOut = false
    private var reaped = false
    private let completion: @Sendable (ChildResult) -> Void

    init(pid: pid_t, stdout: Int32, stderr: Int32, completion: @escaping @Sendable (ChildResult) -> Void) {
        self.pid = pid
        self.completion = completion
        handles = [FileHandle(fileDescriptor: stdout, closeOnDealloc: true),
                   FileHandle(fileDescriptor: stderr, closeOnDealloc: true)]
    }

    func begin(timeout: Double) {
        for index in 0..<2 {
            handles[index]?.readabilityHandler = { [self] handle in
                let data = handle.availableData
                if data.isEmpty { streamEnded(index) } else { append(data, to: index) }
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [self] in expire() }
    }

    private func append(_ data: Data, to index: Int) {
        lock.lock()
        buffers[index].append(data)
        lock.unlock()
    }

    private func streamEnded(_ index: Int) {
        lock.lock()
        guard let handle = handles[index] else { lock.unlock(); return }
        handle.readabilityHandler = nil
        handles[index] = nil
        open -= 1
        let both = open == 0
        lock.unlock()
        if both { reap() }
    }

    /// Past the timeout: the whole group gets SIGTERM, then SIGKILL; if a pipe
    /// is still held open after that (a grandchild that left the group), it
    /// is abandoned and the child reaped anyway.
    private func expire() {
        lock.lock()
        let running = !reaped
        if running { timedOut = true }
        lock.unlock()
        guard running else { return }
        kill(-pid, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + Spawn.grace) { [self] in
            lock.lock(); let still = !reaped; lock.unlock()
            guard still else { return }
            kill(-pid, SIGKILL)
            DispatchQueue.global().asyncAfter(deadline: .now() + Spawn.grace) { [self] in
                lock.lock()
                let abandon = !reaped && open > 0
                if abandon {
                    for index in 0..<2 {
                        handles[index]?.readabilityHandler = nil
                        handles[index] = nil
                    }
                    open = 0
                }
                lock.unlock()
                if abandon { reap() }
            }
        }
    }

    private func reap() {
        DispatchQueue.global().async { [self] in
            var raw: Int32 = 0
            while waitpid(pid, &raw, 0) == -1 && errno == EINTR {}
            let signal = raw & 0x7f
            let status = signal == 0 ? (raw >> 8) & 0xff : 128 + signal
            lock.lock()
            guard !reaped else { lock.unlock(); return }
            reaped = true
            let result = ChildResult(status: status, stdout: buffers[0], stderr: buffers[1], timedOut: timedOut)
            lock.unlock()
            completion(result)
        }
    }
}
