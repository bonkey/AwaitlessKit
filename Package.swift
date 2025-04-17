// swift-tools-version: 5.10

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "AwaitlessKit",
    platforms: [.macOS(.v14), .iOS(.v15), .tvOS(.v13), .watchOS(.v10), .macCatalyst(.v13)],
    products: [
        .library(name: "AwaitlessKit", targets: ["AwaitlessKit"]),
    ],
    dependencies: [
        .package(url: "git@github.com:swiftlang/swift-syntax.git", from: "600.0.0-latest"),
        .package(url: "git@github.com:pointfreeco/swift-macro-testing.git", from: "0.6.2"),
    ],
    targets: [
        .target(
            name: "AwaitlessKit",
            dependencies: ["AwaitlessKitMacros"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]),
        .macro(
            name: "AwaitlessKitMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]),
        .executableTarget(
            name: "AwaitlessApp",
            dependencies: ["AwaitlessKit"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]),
        .testTarget(
            name: "AwaitlessKitTests",
            dependencies: [
                "AwaitlessKit",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]),
    ])
