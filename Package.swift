// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PodSync",
    platforms: [.macOS(.v13)],
    targets: [
        // C target that wraps the pre-compiled LibGPod.framework
        .target(
            name: "CLibGPod",
            path: "Sources/CLibGPod",
            publicHeadersPath: "include",
            linkerSettings: [
                .unsafeFlags([
                    "-F", "Frameworks",
                    "-framework", "LibGPod",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        // Main app target
        .executableTarget(
            name: "PodSync",
            dependencies: ["CLibGPod"],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "Frameworks",
                    "-framework", "LibGPod",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "PodSyncTests",
            dependencies: ["PodSync"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
