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
        // .package(url: "https://github.com/apple/swift-syntax.git", .upToNextMajor(from: "510.0.0")),
        .package(url: "git@github.com:swiftlang/swift-syntax.git", from: "600.0.0-latest"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.6.2"),
    ],
    targets: [
        .target(
            name: "AwaitlessKit",
            dependencies: ["AwaitlessKitMacros"]),
        .macro(
            name: "AwaitlessKitMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]),
        .executableTarget(
            name: "AwaitlessApp",
            dependencies: ["AwaitlessKit"]),
        .testTarget(
            name: "AwaitlessKitTests",
            dependencies: [
                "AwaitlessKit",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ]),
    ])
