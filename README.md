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

## Development

### Running Tests
```bash
# Run all tests
swift test

# Run specific test target
swift test --filter WorkoutTrackerTests
swift test --filter WorkoutTrackerIntegrationTests
```

### Test Coverage
```bash
# Generate coverage report
./scripts/generate-coverage.sh

# View detailed HTML report
open coverage/html/index.html
```

Current coverage focuses on business logic:
- **Models & Services**: 95-100% coverage
- **ViewModels**: 100% coverage  
- **Overall Project**: 12.26% line coverage, 47% function coverage

See [COVERAGE.md](COVERAGE.md) for detailed coverage information and strategy.

### Code Quality
The project includes automated quality gates:
- **SwiftLint**: Enforces code style and best practices
- **Pre-commit hooks**: Run linting and build verification
- **Pre-push hooks**: Run complete test suite
- **CI/CD**: Automated testing and coverage reporting

```bash
# Manual quality checks
swiftlint
swift build
swift test
```

### Security & Dependencies
```bash
# Run security scan
./scripts/check-dependencies.sh

# View security reports
ls security/
```

Automated security features:
- **Dependency vulnerability scanning**: Checks all Swift packages against GitHub Security Advisories
- **License compliance**: Validates dependency licenses
- **Dependabot integration**: Automated dependency updates
- **CI security reporting**: Vulnerability summaries on pull requests

Current status: **4 dependencies, no critical vulnerabilities**

See [SECURITY.md](SECURITY.md) for detailed security information and incident response procedures.

### Code Complexity Analysis
```bash
# Run complexity analysis
./scripts/analyze-complexity.sh

# View detailed reports
open complexity/complexity-report.html
```

Automated complexity monitoring:
- **Cyclomatic complexity**: Measures function complexity (current avg: 1.3)
- **Function length**: Tracks lines of code per function (max: 15 lines)
- **Parameter count**: Monitors function parameter counts (max: 3 params)
- **File size**: Measures lines of code per file (max: 69 lines)

Current status: **271 NLOC, 15 functions, 0 threshold violations**

See [COMPLEXITY.md](COMPLEXITY.md) for detailed complexity analysis and code quality guidelines.

### API Documentation
```bash
# Generate documentation
./scripts/generate-docs.sh

# View documentation
open docs/html/index.html
```

Automated documentation features:
- **HTML Documentation**: Interactive API reference with navigation
- **Source Comment Extraction**: Comprehensive documentation from `///` comments
- **Architecture Documentation**: MVVM pattern and component relationships
- **CI Integration**: Automatic documentation generation and PR artifacts

Current status: **9 Swift files, 24 documentation comments, 100% API coverage**

See [DOCUMENTATION.md](DOCUMENTATION.md) for detailed documentation generation and standards.

### CI/CD Optimization
See [CI Optimization Best Practices](docs/CI-OPTIMIZATION-BEST-PRACTICES.md) for guidelines on maintaining fast CI pipelines and [CLAUDE.md](CLAUDE.md) for CI troubleshooting.

### Spell Checking
```bash
# Run spell check
./scripts/check-spelling.sh

# View spelling reports
cat spelling/spelling-summary.txt
```

Automated spell checking features:
- **Source Code Analysis**: Checks Swift documentation comments and user-facing strings
- **Documentation Verification**: Validates spelling in markdown files and guides
- **Technical Term Recognition**: Ignores 76 project-specific technical terms
- **CI Integration**: Automatic spell checking on pull requests with detailed reports

Current status: **25 files analyzed, 0 spelling issues, professional quality text**

See [SPELLING.md](SPELLING.md) for detailed spell checking configuration and guidelines.

### TestFlight Deployment
```bash
# Setup deployment system
./scripts/setup-deployment.sh

# Manual deployment via GitHub Actions
# (Go to Actions tab → Deploy to TestFlight → Run workflow)

# Automatic deployment via tags
git tag v1.0.0
git push origin v1.0.0
```

Automated deployment features:
- **Fastlane Integration**: Industry-standard iOS deployment automation
- **Code Signing Management**: Secure certificate and provisioning profile handling
- **GitHub Actions Workflow**: Automated builds triggered by tags or manual dispatch
- **TestFlight Upload**: Direct integration with App Store Connect and TestFlight

Current status: **Complete deployment pipeline ready for configuration**

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed setup instructions and configuration guide.

### Release Management
```bash
# Check what the next version would be
./scripts/check-next-version.sh

# Automatically determine and bump version
./scripts/release.sh --auto-version

# Manual version specification
./scripts/release.sh --version 1.0.0

# Preview any release without making changes
./scripts/release.sh --auto-version --dry-run
```

Automated version bumping features:
- **Conventional Commit Analysis**: Determines version bump from commit types
- **Semantic Versioning Rules**: feat→minor, fix→patch, BREAKING→major
- **Project File Updates**: Automatically updates Info.plist and build numbers
- **Safety Validation**: Prevents releases with uncommitted changes
- **CI/CD Integration**: Automatic releases triggered on main branch pushes

Version bump rules:
- `feat:` commits → **minor** version bump (new features)
- `fix:` commits → **patch** version bump (bug fixes)
- `BREAKING CHANGE` or `feat!:` → **major** version bump
- Other types (`docs:`, `chore:`, etc.) → **patch** version bump

Automated release features:
- **Conventional Commit Parsing**: Categorizes commits by type (feat, fix, docs, etc.)
- **Semantic Version Support**: Validates and processes semantic versioning
- **Breaking Change Detection**: Identifies breaking changes from commit messages
- **GitHub Integration**: Automated release creation with formatted notes
- **TestFlight Integration**: Automatic deployment triggered by git tags

Current status: **Complete release automation with automated version bumping**

See release-notes/ directory for generated release documentation and summaries.