// swift-tools-version: 5.10

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Noasync",
    platforms: [.macOS(.v10_15), .iOS(.v15), .tvOS(.v13), .watchOS(.v10), .macCatalyst(.v13)],
    products: [
        .library(name: "TaskNoasync", targets: ["TaskNoasync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", .upToNextMajor(from: "510.0.0")),
    ],
    targets: [
        .macro(
            name: "NoasyncMacro",
            dependencies: [
                "TaskNoasync",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]),
        .target(name: "TaskNoasync"),
        .executableTarget(name: "NoasyncApp", dependencies: ["NoasyncMacro", "TaskNoasync"]),
        .testTarget(
            name: "NoasyncMacroTests",
            dependencies: [
                "NoasyncMacro",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]),
    ])
