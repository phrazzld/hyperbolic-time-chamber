# WorkoutTracker

A simple iOS workout tracker prototype built with SwiftUI and Swift Package Manager.

## Requirements
- Xcode 15 or later (required for CLI build instructions)
- iOS 15 or later

## Running the App
1. Open `Package.swift` in Xcode.
2. Select the `WorkoutTracker` scheme and an iOS Simulator.
3. Configure the app’s Info.plist:
   - In the scheme’s Run action, under the Info tab, uncheck “Generate Info.plist File”.
   - Check “Use Info.plist File” and choose `Sources/WorkoutTracker/Info.plist`.
4. Build and run.

Alternatively, build & launch from the CLI:
> **Note:** Building from the command line this way requires Xcode 15 or later. If you’re on Xcode 14 or earlier, generate an Xcode project and use `-project` instead of `-package-path`:

```bash
swift package generate-xcodeproj --output .
xcodebuild \
  -project WorkoutTracker.xcodeproj \
  -scheme WorkoutTracker \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  -derivedDataPath build \
  INFOPLIST_FILE=Sources/WorkoutTracker/Info.plist \
  clean build
```

```bash
# Build with custom Info.plist
xcodebuild \
  -package-path . \
  -scheme WorkoutTracker \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 14' \
  -derivedDataPath build \
  INFOPLIST_FILE=Sources/WorkoutTracker/Info.plist \
  clean build

# Install & launch in the simulator
APP_PATH="build/Build/Products/Debug-iphonesimulator/WorkoutTracker.app"
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.yourcompany.WorkoutTracker
```

## Features
- Track arbitrary exercises with multiple sets (reps, optional weight).
- View exercise history grouped by day.
- Export all workout data as JSON via Share Sheet.