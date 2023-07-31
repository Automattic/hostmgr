// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hostmgr",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "hostmgr", targets: ["hostmgr"]),
        .executable(name: "hostmgr-helper", targets: ["hostmgr-helper"]),
        .library(name: "libhostmgr", targets: ["libhostmgr"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.4"),
        .package(url: "https://github.com/jkmassel/tinys3.git", branch: "main"),
        .package(url: "https://github.com/jkmassel/prlctl.git", .upToNextMinor(from: "1.22.0")),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/jkmassel/kcpassword-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-tools-support-core", from: "0.2.5"),
        .package(url: "https://github.com/vapor/console-kit.git", .upToNextMajor(from: "4.5.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "hostmgr",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "kcpassword", package: "kcpassword-swift"),
                .target(name: "libhostmgr")
            ],
            exclude: [
                "hostmgr.entitlements",
            ]
        ),
        .executableTarget(
            name: "hostmgr-helper",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .target(name: "libhostmgr")
            ]
        ),
        .target(
            name: "libhostmgr",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "TSCBasic", package: "swift-tools-support-core"),
                .product(name: "tinys3", package: "tinys3"),
                .product(name: "ConsoleKit", package: "console-kit"),
                .product(name: "prlctl", package: "prlctl"),
            ]
        ),
        .testTarget(
            name: "libhostmgrTests",
            dependencies: [
                "libhostmgr",
            ],
            resources: [
                .copy("resources/configurations/0.6.0.json"),
                .copy("resources/configurations/defaults.json"),
                .copy("resources/buildkite-environment-variables-basic-expected-output.txt"),
                .copy("resources/buildkite-environment-variables-basic.env"),
                .copy("resources/buildkite-environment-variables-with-code-quotes.env"),
                .copy("resources/buildkite-commit-message-original.txt"),
                .copy("resources/buildkite-commit-message-expected.txt"),
                .copy("resources/dhcpd_leases"),
                .copy("resources/dotenv-fixtures.env"),
                .copy("resources/file-hasher-test-1"),
                .copy("resources/mac-hardware-model-data.dat"),
            ]
        ),
    ]
)
