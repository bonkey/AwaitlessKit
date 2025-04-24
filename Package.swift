// swift-tools-version: 5.10

import CompilerPluginSupport
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("StrictConcurrency"),
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("DeprecateApplicationMain"),
    .enableUpcomingFeature("ImportObjcForwardDeclarations"),
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("IsolatedDefaultValues"),
    .enableUpcomingFeature("GlobalConcurrency"),
    .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"]),
]

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
        .executableTarget(
            name: "AwaitlessApp",
            dependencies: ["AwaitlessKit"],
            swiftSettings: swiftSettings),
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
