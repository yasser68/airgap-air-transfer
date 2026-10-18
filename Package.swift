// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AirGapReceiver",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "AirGapReceiver",
            targets: ["AirGapReceiver"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AirGapReceiver",
            path: "Sources/AirGapReceiver"
        )
    ]
)
