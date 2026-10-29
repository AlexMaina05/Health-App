// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RosettaEdgeCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "RosettaEdgeCore",
            targets: ["RosettaEdgeCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RosettaEdgeCore",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("HealthKit"),
                .linkedFramework("Vision"),
                .linkedFramework("PDFKit", .when(platforms: [.iOS, .macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "RosettaEdgeCoreTests",
            dependencies: ["RosettaEdgeCore"]
        )
    ]
)
