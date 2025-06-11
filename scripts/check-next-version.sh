#!/bin/bash
set -e

# Simple script to check what the next version would be based on conventional commits
# Useful for developers to preview version changes

echo "🔍 Checking Next Version"
echo "========================"

# Run version analysis
python3 scripts/bump-version.py --dry-run --output-json /tmp/version-check.json

if [ -f "/tmp/version-check.json" ]; then
    # Parse and display results in a friendly format
    python3 -c "
import json

with open('/tmp/version-check.json', 'r') as f:
    data = json.load(f)

print(f\"📊 Version Analysis:\")
print(f\"  Current Version: {data['current_version']}\")
print(f\"  Next Version: {data['new_version']}\")
print(f\"  Bump Type: {data['bump_type']}\")
print(f\"  Commits Analyzed: {data['commits_analyzed']}\")
print(f\"  Version Will Change: {'Yes' if data['version_changed'] else 'No'}\")

if data['version_changed']:
    print(f\"\")
    print(f\"🚀 Next release will be v{data['new_version']}\")
    
    if data['bump_type'] == 'major':
        print(f\"⚠️  MAJOR version bump detected - this indicates breaking changes!\")
    elif data['bump_type'] == 'minor':
        print(f\"✨ MINOR version bump - new features added\")
    elif data['bump_type'] == 'patch':
        print(f\"🐛 PATCH version bump - bug fixes and improvements\")
else:
    print(f\"\")
    print(f\"ℹ️  No version change needed based on recent commits\")

print(f\"\")
print(f\"💡 To create this release:\")
print(f\"   ./scripts/release.sh --auto-version\")
"
    
    rm -f /tmp/version-check.json
else
    echo "❌ Failed to analyze version"
    exit 1
fi