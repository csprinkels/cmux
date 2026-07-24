// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CmuxAIProviders",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CmuxAIProviders",
            targets: ["CmuxAIProviders"]
        ),
    ],
    targets: [
        .target(
            name: "CmuxAIProviders",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "CmuxAIProvidersTests",
            dependencies: ["CmuxAIProviders"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
    ]
)
