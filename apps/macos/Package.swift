// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CosmogonyMacOS",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CosmogonyCore", targets: ["CosmogonyCore"]),
        .executable(name: "CosmogonyApp", targets: ["CosmogonyApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0")
    ],
    targets: [
        .target(
            name: "CosmogonyCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/CosmogonyCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("Network"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "CosmogonyApp",
            dependencies: [
                "CosmogonyCore"
            ],
            path: "Sources/CosmogonyApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "CosmogonyChecks",
            dependencies: [
                "CosmogonyCore"
            ],
            path: "Sources/CosmogonyChecks"
        )
    ]
)
