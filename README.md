# swift-git-survey

The state of every git working tree under some folders, from Swift: what is uncommitted, unpushed, untagged, stashed or half merged. Reads only, runs git a few times per repository with bounded concurrency, and fetches only when asked.

```swift
import GitSurvey

let report = try await Survey.run(roots: ["/Users/me/code", "/Users/me/work"])
for repo in report.repositories where repo.needsAttention {
    print(repo.path, repo.problems)              // ["dirty", "ahead"] as Problem values
}

let here = try await Survey.inspect(path: FileManager.default.currentDirectoryPath)
here.repositories[0].latestTag                 // TagState(name: "v1.2.0", commitsSince: 3, onRemote: nil)

// Fetch first (remote-tracking refs only) and ask GitHub about releases:
let full = try await Survey.run(roots: ["/Users/me/code"],
                                options: SurveyOptions(fetch: true, releases: true))
full.repositories.first?.latestTag?.onRemote   // true / false, known after a fetch
full.repositories.first?.release?.state        // .published, .noAssets, .draft, .missing, .unknown
```

The `repos` CLI is the front end.

## What each repository reports

| Field | From |
|---|---|
| branch, detached, HEAD, upstream, upstream gone, ahead/behind | `git status --porcelain=v2 --branch` |
| staged, unstaged, untracked, conflicted | the same status: records `1`/`2` (the index and worktree columns), `?`, `u` |
| stashes | the same status, `--show-stash` |
| half-done operation (merge, rebase, am, cherry-pick, revert, bisect) | marker files in the git directory: `MERGE_HEAD`, `rebase-merge/`, `rebase-apply/`, … |
| last commit date and subject | `git log -1` |
| nearest tag and commits since it | the same `git log -1`, through `%(describe:tags=true)` |
| other branches with no remote counterpart, or ahead of their upstream | `git for-each-ref refs/heads refs/remotes` with `%(upstream:track)` and `%(ahead-behind:HEAD)` |
| remotes, and the current branch's remote | the repository's config file, read directly (`git config` when it includes others) |
| tag on the remote, fetch outcome | with `fetch`: `git fetch` and `git ls-remote --tags` |
| GitHub release with an asset | with `releases`: `gh release view` |

`problems` lists what wants attention, in this order: `dirty`, `conflicted`, `in_progress`, `detached`, `ahead`, `behind`, `no_upstream`, `no_remote`, `stashed`, `local_branches`, `untagged`, `unpushed_tag`, `fetch_failed`, `no_release`, `no_release_asset`, `error`. `untagged` (commits since the latest tag) is informational: it is listed but `needsAttention` ignores it, because commits since a tag are most projects' normal state.

## Read-only, and how

- `git --no-optional-locks status`: a plain `git status` refreshes the index and writes it back when file times have moved, which races with whatever else (an editor, an agent) is using the repository. The tests move a tracked file's mtime and check that nothing under the fixture changes.
- `-c core.fsmonitor=false`, so no fsmonitor daemon is started for anyone, and `log.showSignature=false`, so `log` never runs gpg.
- Children start in a session of their own (`POSIX_SPAWN_SETSID`) with stdin from `/dev/null`, `GIT_TERMINAL_PROMPT=0`, an empty `GIT_ASKPASS` and `SSH_ASKPASS_REQUIRE=never`. ssh asking about a host key or a passphrase, or git asking for a password, fails at once instead of waiting on a terminal. Measured: an HTTPS remote that wanted a password failed in well under its timeout with git's own "could not read Password" line.
- A timeout stops the whole process group, so git and the ssh it started go together. The fetch fixture's "ssh" sleeps for a minute and the survey still ends at its 2 s timeout.
- `fetch` runs `git fetch --quiet --no-tags --no-write-fetch-head --no-auto-maintenance --recurse-submodules=no <remote>`. That updates remote-tracking refs and the objects they need, and nothing else: no local branch, tag, index, working file, stash or `FETCH_HEAD`, and nothing on the remote. The tests check the local tags, HEAD, the index and the absence of `FETCH_HEAD` after a fetch. Fetches that fail or time out are recorded per repository and never stop the survey.

## Finding repositories

A folder with a `.git` entry is a working tree. The entry can be a directory, or a file pointing at a git directory (linked worktrees, submodules, `--separate-git-dir`). Folders are read with `readdir` and symbolic links are never followed. The search skips hidden folders, `.build`, `node_modules`, `Packages`, `DerivedData`, `.swiftpm`, `checkouts`, and bundles such as `.app` or `.photoslibrary`. It also does not look inside a working tree unless `nested` is set. With `home`, it also skips `Library`, `Applications`, `Pictures`, `Music`, `Movies`, `Public` and cloud-storage folders (Dropbox, Google Drive, OneDrive, Box, Creative Cloud) at the top of the root. Bare repositories have no working tree and are not listed.

## Measured

On a 14-core Apple silicon Mac, macOS 27, git 2.56, release build, 2026-10-19:

- **523 repositories in 1.6 s offline** (discovery 0.1 s). That is 3 processes per repository; each git process costs about 8 ms to start, which is most of the time. Concurrency past 16 gained nothing.
- **Reading the config file instead of running `git config`** cut a quarter of the processes (1.8 s → 1.6 s). The reader agreed with `git config -z --get-regexp` on all 523 repositories (an opt-in test: `GITSURVEY_COMPARE_ROOT=<folder> swift test --filter agreesWithGitOnARealFolder`).
- **With `fetch`**, each repository waits on its remote: 104 s at 14 at once, 47 s at 32 (the default with a fetch), 24 s at 64, over ssh to GitHub. 521 of 522 remotes fetched; the one failure was an HTTPS remote wanting a password, recorded and moved past.
- **With `releases`**, 30 s for 377 tagged GitHub repositories, 8 gh calls at once.
- **A whole home folder (`home`)**: 609 repositories in 2.3 s, discovery 0.4 s.

## Limits

- Ahead and behind are against remote-tracking refs as last fetched; without `fetch` they can be stale.
- Whether the latest tag is on the remote is unknown (`nil`) without `fetch`: only the remote can say. With it, the check is by name, not by hash.
- "Latest tag" is the nearest tag reachable from HEAD (`describe --tags`), not the newest tag in the repository.
- Untracked counts follow `git status`: a new folder counts once.
- `localOnlyBranches` needs git 2.41 for `%(ahead-behind:HEAD)` to leave out branches already merged into HEAD; on older git every branch without a remote counterpart is listed. git 2.35 is the minimum (`status --show-stash`).
- A linked worktree shares its main repository's stashes and branches, so both report them.
- Releases are asked of github.com only. A remote behind an ssh host alias (`github-work:owner/repo`) is not recognised.

## Requirements

macOS 14+. git 2.35 or later on PATH (or in /opt/homebrew/bin, /usr/local/bin, /usr/bin); `gh`, signed in, for release checks.

## License

MIT — see [LICENSE](LICENSE).
