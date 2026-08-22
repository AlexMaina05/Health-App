// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RosettaHealthCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "RosettaHealthCore",
            targets: ["RosettaHealthCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RosettaHealthCore",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("HealthKit"),
                .linkedFramework("Vision"),
                .linkedFramework("PDFKit", .when(platforms: [.iOS, .macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
            ]
        ),
        .testTarget(
            name: "RosettaHealthCoreTests",
            dependencies: ["RosettaHealthCore"]
        )
    ]
)
