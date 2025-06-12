# Development Workflow

## Quick Start

Build and launch the app in the iPhone 16 simulator:

```bash
./run.sh
```

## Script Options

```bash
./run.sh [OPTIONS] [DEVICE_NAME]
```

### Available Options:
- `--clean` - Perform clean build (slower but ensures fresh build)
- `--no-sim` - Don't automatically open Simulator app
- `--help` - Show usage information

### Examples:

```bash
# Basic build and run (iPhone 16)
./run.sh

# Clean build and run
./run.sh --clean

# Run on different device
./run.sh "iPhone 15 Pro"

# Build and run without opening Simulator app
./run.sh --no-sim
```

## What the Script Does:

1. **Device Management**: Finds and boots the target iOS Simulator device
2. **Build**: Compiles the Xcode project for the simulator
3. **Install**: Installs the app bundle on the simulator
4. **Launch**: Starts the app and reports the process ID
5. **Open Simulator**: Brings the Simulator app to the foreground

## Manual Commands (for debugging):

If you need to run individual steps manually:

```bash
# List available devices
xcrun simctl list devices

# Boot a specific device
xcrun simctl boot "iPhone 16"

# Build manually
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Install manually
xcrun simctl install "iPhone 16" "/path/to/WorkoutTracker.app"

# Launch manually
xcrun simctl launch "iPhone 16" com.yourcompany.WorkoutTracker

# Check app status
xcrun simctl listapps "iPhone 16" | grep WorkoutTracker
```

## Troubleshooting:

- **Build fails**: Check that all source files are properly included in the Xcode project
- **Install fails**: Verify the app bundle was built successfully and simulator is booted
- **Launch fails**: Check the app's Info.plist configuration and iOS version compatibility
- **Simulator not found**: Use `xcrun simctl list devices` to see available devices