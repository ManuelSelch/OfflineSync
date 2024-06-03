// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OfflineSync",
    platforms: [
        .iOS(.v16), .macOS(.v13), .macCatalyst(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OfflineSync",
            targets: ["OfflineSync"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Moya/Moya.git", .upToNextMajor(from: "15.0.0")),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", .upToNextMajor(from: "0.15.3")),
        .package(url: "https://github.com/ManuelSelch/Redux.git", .upToNextMajor(from: "1.1.3"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OfflineSync",
            dependencies: [
                .product(name: "Moya", package: "Moya"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Redux", package: "Redux")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "OfflineSyncTests",
            dependencies: ["OfflineSync"]),
    ]
)
