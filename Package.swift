// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let sharedSettings: [SwiftSetting] = [
//    .enableExperimentalFeature("StrictConcurrency")
    .enableUpcomingFeature("BareSlashRegexLiterals")
]

let package = Package(
    name: "hostmgr",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "hostmgr", targets: ["hostmgr"]),
        .executable(name: "hostmgr-helper", targets: ["hostmgr-helper"]),
        .executable(name: "tinys3-cli", targets: ["tinys3-cli"]),
        .library(name: "libhostmgr", targets: ["libhostmgr"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.1.4"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
        .package(url: "https://github.com/jkmassel/kcpassword-swift.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/console-kit.git", .upToNextMajor(from: "4.9.0")),
        .package(url: "https://github.com/swhitty/FlyingFox.git", .upToNextMajor(from: "0.12.2")),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", .upToNextMajor(from: "8.29.0")),
        .package(url: "https://github.com/swiftpackages/DotEnv.git", from: "3.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "hostmgr",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "kcpassword", package: "kcpassword-swift"),
                .target(name: "libhostmgr")
            ],
            exclude: [
                "hostmgr.entitlements",
            ],
            swiftSettings: sharedSettings
        ),
        .executableTarget(
            name: "hostmgr-helper",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Sentry", package: "sentry-cocoa"),
                .target(name: "libhostmgr")
            ],
            swiftSettings: sharedSettings
        ),
        .target(
            name: "libhostmgr",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "tinys3"),
                .product(name: "ConsoleKit", package: "console-kit"),
                .product(name: "FlyingFox", package: "FlyingFox")
            ],
            swiftSettings: sharedSettings
        ),
        .testTarget(
            name: "libhostmgrTests",
            dependencies: [
                "libhostmgr",
                .product(name: "DotEnv", package: "DotEnv"),
            ],
            resources: [
                .copy("resources/server-responses/caddy-file-list.json"),
                .copy("resources/buildkite-environment-variables-basic-expected-output.txt"),
                .copy("resources/buildkite-environment-variables-basic.env"),
                .copy("resources/buildkite-environment-variables-with-code-quotes.env"),
                .copy("resources/buildkite-commit-message-original.txt"),
                .copy("resources/buildkite-commit-message-expected.txt"),
                .copy("resources/dhcpd_leases-1"),
                .copy("resources/dhcpd_leases-2"),
                .copy("resources/dotenv-fixtures.env"),
                .copy("resources/file-hasher-test-1"),
                .copy("resources/mac-hardware-model-data.dat"),
                .copy("resources/usage-file-sample"),
                .copy("resources/vm-config-file-sample-1.json"),
                .copy("resources/vm-config-file-sample-2.json"),
                .copy("resources/vm-config-file-sample-3.json")
            ]
        ),
        .executableTarget(
            name: "tinys3-cli",
            dependencies: [
                "tinys3",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "tinys3",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: sharedSettings
        ),
        .testTarget(
            name: "tinys3Tests",
            dependencies: [
                "tinys3",
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            resources: [
                .copy("resources/aws-config-file-multiple.txt"),
                .copy("resources/aws-config-file-no-region.txt"),
                .copy("resources/aws-config-file-single.txt"),
                .copy("resources/aws-credentials-file-multiple.txt"),
                .copy("resources/aws-credentials-file-no-region.txt"),
                .copy("resources/aws-credentials-file-single.txt"),
                .copy("resources/CompleteMultipartUploadDocument.txt"),
                .copy("resources/CompleteMultipartUploadRequest.txt"),
                .copy("resources/CreateMultipartUpload.xml"),
                .copy("resources/EmptyXML.xml"),
                .copy("resources/ErrorDataRedirect.xml"),
                .copy("resources/EscapedCompleteMultipartBody.xml"),
                .copy("resources/ListBucketData.xml"),
                .copy("resources/ListBucketDataEmpty.xml"),
                .copy("resources/ListBucketDataInvalid.xml"),
                .copy("resources/ListMultipartUploadsResult.xml"),
                .copy("resources/ListPartsResponseResult.xml"),
            ]
        ),
    ]
)
