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
    dependencies: [],
    targets: [
        .executableTarget(
            name: "WorkoutTracker",
            dependencies: [],
            path: "Sources/WorkoutTracker",
            // The app’s Info.plist is provided via the INFOPLIST_FILE build setting in Xcode or CLI (see README)
        )
    ]
)