// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableExperimentalFeature("AccessLevelOnImport"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
    name: "AwaitlessKit",
    platforms: [.macOS(.v14), .iOS(.v15), .tvOS(.v13), .watchOS(.v10), .macCatalyst(.v14)],
    products: [
        .library(name: "AwaitlessKit", targets: ["AwaitlessKit"]),
        .library(name: "AwaitlessKit-PromiseKit", targets: ["AwaitlessKitPromiseKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "600.0.1"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.6.3"),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "AwaitlessKit",
            dependencies: ["AwaitlessKitMacros", "AwaitlessCore"],
            swiftSettings: swiftSettings),
        .target(
            name: "AwaitlessKitPromiseKit",
            dependencies: [
                "AwaitlessKitPromiseMacros", 
                "AwaitlessCore",
                .product(name: "PromiseKit", package: "PromiseKit")
            ],
            swiftSettings: swiftSettings),
        .macro(
            name: "AwaitlessKitMacros",
            dependencies: [
                "AwaitlessCore",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            swiftSettings: swiftSettings),
        .macro(
            name: "AwaitlessKitPromiseMacros",
            dependencies: [
                "AwaitlessCore",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "PromiseKit", package: "PromiseKit")
            ],
            swiftSettings: swiftSettings),
        .target(
            name: "AwaitlessCore",
            swiftSettings: swiftSettings),
        .testTarget(
            name: "AwaitlessKitTests",
            dependencies: [
                "AwaitlessKit",
                "AwaitlessKitMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ],
            swiftSettings: swiftSettings),
        .testTarget(
            name: "AwaitlessKitPromiseTests",
            dependencies: [
                "AwaitlessKitPromiseKit",
                "AwaitlessKitPromiseMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "MacroTesting", package: "swift-macro-testing"),
                .product(name: "PromiseKit", package: "PromiseKit")
            ],
            swiftSettings: swiftSettings),
    ],
    swiftLanguageModes: [.v5, .v6])
