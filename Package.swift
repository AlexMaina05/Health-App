// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "RosettaHealthCore",
    platforms: [
        .iOS(.v17)
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
            dependencies: [])
    ]
)
