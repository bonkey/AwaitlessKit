// swift-tools-version: 5.10

import CompilerPluginSupport
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("StrictConcurrency"),

    .enableExperimentalFeature("AccessLevelOnImport"),
    .enableUpcomingFeature("InternalImportsByDefault"),

    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("DeprecateApplicationMain"),
    .enableUpcomingFeature("ImportObjcForwardDeclarations"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("IsolatedDefaultValues"),
    .enableUpcomingFeature("GlobalConcurrency"),
]

let package = Package(
    name: "AwaitlessKit",
    platforms: [.macOS(.v14), .iOS(.v15), .tvOS(.v13), .watchOS(.v10), .macCatalyst(.v14)],
    products: [
        .library(name: "AwaitlessKit", targets: ["AwaitlessKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "510.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.6.3"),
    ],
    targets: [
        .target(
            name: "AwaitlessKit",
            dependencies: ["AwaitlessKitMacros", "AwaitlessCore"],
            swiftSettings: swiftSettings),
        .macro(
            name: "AwaitlessKitMacros",
            dependencies: [
                "AwaitlessCore",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
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
    ])
