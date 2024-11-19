// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OfflineSync",
    platforms: [
        .iOS(.v16), .macOS(.v13), .macCatalyst(.v16)
    ],
    products: [
        .library(
            name: "OfflineSync",
            targets: ["OfflineSyncCore", "OfflineSyncServices"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Moya/Moya.git", .upToNextMajor(from: "15.0.0")),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", .upToNextMajor(from: "0.15.3")),
        .package(url: "https://github.com/ManuelSelch/Dependencies.git", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "OfflineSyncCore",
            dependencies: [
                .product(name: "Moya", package: "Moya"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Dependencies", package: "Dependencies")
            ],
            path: "Sources/Core"
        ),
        
        .target(
            name: "OfflineSyncServices",
            dependencies: [
                "OfflineSyncCore",
                .product(name: "Moya", package: "Moya"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Dependencies", package: "Dependencies")
            ],
            path: "Sources/Services"
        ),
        
        
        .testTarget(
            name: "OfflineSyncTests",
            dependencies: ["OfflineSyncCore", "OfflineSyncServices"]
        ),
    ]
)
