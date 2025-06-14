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
        .target(
            name: "TestConfiguration",
            dependencies: ["WorkoutTracker"],
            path: "Tests/TestConfiguration",
            exclude: ["README.md"],
            resources: [
                .process("ci-config.json"),
                .process("local-config.json")
            ]
        ),
        .testTarget(
            name: "WorkoutTrackerTests",
            dependencies: ["WorkoutTracker", "TestConfiguration"],
            path: "Tests/WorkoutTrackerTests"
        ),
        .testTarget(
            name: "WorkoutTrackerIntegrationTests",
            dependencies: [
                "WorkoutTracker",
                "TestConfiguration",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/WorkoutTrackerIntegrationTests"
        ),
        .testTarget(
            name: "WorkoutTrackerPerformanceTests",
            dependencies: ["WorkoutTracker", "TestConfiguration"],
            path: "Tests/WorkoutTrackerPerformanceTests"
        ),
        .testTarget(
            name: "WorkoutTrackerComprehensiveTests",
            dependencies: ["WorkoutTracker", "TestConfiguration"],
            path: "Tests/WorkoutTrackerComprehensiveTests"
        ),
        .testTarget(
            name: "WorkoutTrackerStressTests",
            dependencies: ["WorkoutTracker", "TestConfiguration"],
            path: "Tests/WorkoutTrackerStressTests"
        )
    ]
)
