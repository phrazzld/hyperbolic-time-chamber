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
            path: "Sources/WorkoutTracker",
            // The app's Info.plist is provided via the INFOPLIST_FILE build setting in Xcode or CLI (see README)
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
        // UI tests excluded from default test run due to timeout issues
        // Run separately with: swift test --filter WorkoutTrackerUITests
        // .testTarget(
        //     name: "WorkoutTrackerUITests",
        //     dependencies: [],
        //     path: "Tests/WorkoutTrackerUITests"
        // )
    ]
)
