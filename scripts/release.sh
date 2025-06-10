#!/bin/bash
set -e

# Automated Release Script
# Generates release notes, creates git tag, and optionally triggers deployment

VERSION=""
DRY_RUN=false
SKIP_TESTS=false
DEPLOY=false

echo "🚀 WorkoutTracker Release Script"
echo "================================"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version|-v)
            VERSION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --deploy)
            DEPLOY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 --version VERSION [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --version, -v VERSION  Version number (required, e.g., 1.0.0)"
            echo "  --dry-run              Show what would be done without making changes"
            echo "  --skip-tests           Skip running tests before release"
            echo "  --deploy               Trigger deployment after release"
            echo "  --help, -h             Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --version 1.0.0                    # Create release v1.0.0"
            echo "  $0 --version 1.0.1 --deploy           # Create and deploy v1.0.1"
            echo "  $0 --version 2.0.0 --dry-run          # Preview v2.0.0 release"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate version
if [ -z "$VERSION" ]; then
    echo "❌ Version is required. Use --version VERSION"
    exit 1
fi

# Validate semantic version format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
    echo "❌ Invalid version format. Use semantic versioning (e.g., 1.0.0, 1.0.0-beta.1)"
    exit 1
fi

TAG_NAME="v$VERSION"

# Check if tag already exists
if git tag -l | grep -q "^$TAG_NAME$"; then
    echo "❌ Tag $TAG_NAME already exists"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "❌ You have uncommitted changes. Commit or stash them first."
    exit 1
fi

echo "📋 Release Configuration:"
echo "  Version: $VERSION"
echo "  Tag: $TAG_NAME"
echo "  Dry Run: $DRY_RUN"
echo "  Skip Tests: $SKIP_TESTS"
echo "  Deploy: $DEPLOY"
echo ""

# Run tests unless skipped
if [ "$SKIP_TESTS" = false ]; then
    echo "🧪 Running tests..."
    if ! swift test; then
        echo "❌ Tests failed. Fix issues before releasing."
        exit 1
    fi
    echo "✅ Tests passed"
fi

# Generate release notes
echo "📝 Generating release notes..."
if ! python3 scripts/generate-release-notes.py --version "$VERSION"; then
    echo "❌ Failed to generate release notes"
    exit 1
fi

# Show preview
echo ""
echo "📄 Release Notes Preview:"
echo "========================="
head -30 release-notes/release-notes.md
if [ $(wc -l < release-notes/release-notes.md) -gt 30 ]; then
    echo "... (truncated, see release-notes/release-notes.md for full content)"
fi
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN - Would perform these actions:"
    echo "  1. Create git tag: $TAG_NAME"
    echo "  2. Push tag to origin"
    if [ "$DEPLOY" = true ]; then
        echo "  3. Trigger deployment workflow"
    fi
    echo ""
    echo "✅ Dry run complete. Use without --dry-run to execute."
    exit 0
fi

# Confirm release
echo "❓ Ready to create release $TAG_NAME?"
echo "   This will create a git tag and push it to origin."
if [ "$DEPLOY" = true ]; then
    echo "   Deployment will be triggered automatically."
fi
echo ""
read -p "Continue? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Release cancelled"
    exit 1
fi

# Create and push tag
echo "🏷️ Creating git tag $TAG_NAME..."
git tag -a "$TAG_NAME" -m "Release $VERSION

$(cat release-notes/release-notes.md)"

echo "📤 Pushing tag to origin..."
git push origin "$TAG_NAME"

echo "✅ Release $TAG_NAME created successfully!"

# Add to changelog
if [ -f "CHANGELOG.md" ]; then
    echo "📚 Updating CHANGELOG.md..."
    temp_file=$(mktemp)
    cat release-notes/release-notes.md > "$temp_file"
    echo "" >> "$temp_file"
    echo "" >> "$temp_file"
    if [ -f "CHANGELOG.md" ]; then
        cat CHANGELOG.md >> "$temp_file"
    fi
    mv "$temp_file" CHANGELOG.md
    
    git add CHANGELOG.md
    git commit -m "docs: update CHANGELOG.md for $VERSION"
    git push origin main
    echo "✅ CHANGELOG.md updated"
fi

# Trigger deployment if requested
if [ "$DEPLOY" = true ]; then
    echo "🚀 Triggering deployment..."
    echo "   Deployment will start automatically via GitHub Actions"
    echo "   Monitor progress at: https://github.com/$(git remote get-url origin | sed 's/.*github.com[:/]\([^.]*\).*/\1/')/actions"
fi

echo ""
echo "🎉 Release $TAG_NAME completed successfully!"
echo ""
echo "📋 Next steps:"
echo "  • Monitor deployment in GitHub Actions (if enabled)"
echo "  • Update App Store Connect metadata"
echo "  • Notify team of release"
echo ""
echo "📄 Release artifacts:"
echo "  • Release notes: release-notes/release-notes.md"
echo "  • Summary JSON: release-notes/release-summary.json"
echo "  • Git tag: $TAG_NAME"