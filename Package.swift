// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WorkoutTracker",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(name: "WorkoutTracker", targets: ["WorkoutTracker"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0")
    ],
    targets: [
        .executableTarget(
            name: "WorkoutTracker",
            dependencies: [],
            path: "Sources/WorkoutTracker"
        ),
        .testTarget(
            name: "WorkoutTrackerTests",
            dependencies: ["WorkoutTracker"],
            path: "Tests/WorkoutTrackerTests"
        ),
        .testTarget(
            name: "WorkoutTrackerIntegrationTests",
            dependencies: [
                "WorkoutTracker",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/WorkoutTrackerIntegrationTests"
        )
    ]
)
