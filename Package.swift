// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "hostmgr",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
        .package(url: "https://github.com/soto-project/soto.git", from: "6.0.0"),
        .package(url: "https://github.com/jkmassel/prlctl.git", from: "1.17.0"),
        .package(url: "https://github.com/ebraraktas/swift-tqdm.git", from: "0.1.2"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(name: "kcpassword", url: "https://github.com/jkmassel/kcpassword-swift.git", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "hostmgr",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SotoS3", package: "soto"),
                .product(name: "prlctl", package: "prlctl"),
                .product(name: "Tqdm", package: "swift-tqdm"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "kcpassword", package: "kcpassword"),
                .target(name: "libhostmgr")
            ]
        ),
        .target(
            name: "libhostmgr",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SotoS3", package: "soto"),
            ]
        ),
        .testTarget(
            name: "libhostmgrTests",
            dependencies: ["libhostmgr"],
            resources: [
                .copy("resources/configurations/0.6.0.json"),
                .copy("resources/configurations/defaults.json"),
            ]
        ),
    ]
)
