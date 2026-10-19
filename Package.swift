// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-git-survey",
    // It runs git (and, for releases, gh) as child processes in their own
    // session: posix_spawn's POSIX_SPAWN_SETSID is an Apple extension.
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "GitSurvey", targets: ["GitSurvey"]),
    ],
    targets: [
        .target(name: "GitSurvey"),
        // Fixtures are built by the tests with real git in a temporary
        // directory: a bare "remote" and clones in every state.
        .testTarget(name: "GitSurveyTests", dependencies: ["GitSurvey"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
