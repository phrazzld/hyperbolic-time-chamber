#!/usr/bin/env python3
"""
Automated semantic version bumping based on conventional commits.
Follows development philosophy: simplicity and explicit contracts.
"""

import re
import subprocess
import json
import argparse
import plistlib
from datetime import datetime
from typing import Optional, Tuple, List
from pathlib import Path
from enum import Enum


class BumpType(Enum):
    """Types of version bumps according to semantic versioning."""
    MAJOR = "major"
    MINOR = "minor" 
    PATCH = "patch"
    NONE = "none"


class SemanticVersion:
    """Simple semantic version handling."""
    
    def __init__(self, version_string: str):
        self.original = version_string
        match = re.match(r'^(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z0-9.-]+))?$', version_string)
        if not match:
            raise ValueError(f"Invalid semantic version: {version_string}")
        
        self.major = int(match.group(1))
        self.minor = int(match.group(2))
        self.patch = int(match.group(3))
        self.prerelease = match.group(4)
    
    def bump(self, bump_type: BumpType) -> 'SemanticVersion':
        """Return new version with specified bump applied."""
        if bump_type == BumpType.MAJOR:
            return SemanticVersion(f"{self.major + 1}.0.0")
        elif bump_type == BumpType.MINOR:
            return SemanticVersion(f"{self.major}.{self.minor + 1}.0")
        elif bump_type == BumpType.PATCH:
            return SemanticVersion(f"{self.major}.{self.minor}.{self.patch + 1}")
        else:  # NONE
            return SemanticVersion(str(self))
    
    def __str__(self) -> str:
        base = f"{self.major}.{self.minor}.{self.patch}"
        return f"{base}-{self.prerelease}" if self.prerelease else base
    
    def __eq__(self, other) -> bool:
        if not isinstance(other, SemanticVersion):
            return False
        return str(self) == str(other)


class CommitAnalyzer:
    """Analyzes conventional commits to determine version bump needed."""
    
    def __init__(self, from_ref: str, to_ref: str = 'HEAD'):
        self.from_ref = from_ref
        self.to_ref = to_ref
    
    def get_commits(self) -> List[str]:
        """Get commit messages between references."""
        try:
            cmd = ['git', 'log', f'{self.from_ref}..{self.to_ref}', '--pretty=format:%s']
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to get git commits: {e}")
    
    def analyze_commit_message(self, message: str) -> BumpType:
        """Analyze single commit message to determine bump type."""
        # Check for breaking changes first (highest priority)
        if ('BREAKING CHANGE' in message.upper() or 
            'BREAKING-CHANGE' in message.upper() or
            re.match(r'^[a-zA-Z]+(\([^)]*\))?!:', message)):
            return BumpType.MAJOR
        
        # Check conventional commit types
        match = re.match(r'^([a-zA-Z]+)(\([^)]*\))?:', message)
        if match:
            commit_type = match.group(1).lower()
            
            # Features trigger minor bumps
            if commit_type == 'feat':
                return BumpType.MINOR
            
            # Bug fixes and other changes trigger patch bumps
            if commit_type in ['fix', 'perf', 'docs', 'style', 'refactor', 'test', 'chore', 'ci', 'build']:
                return BumpType.PATCH
        
        # Non-conventional commits are treated as patch changes
        return BumpType.PATCH
    
    def determine_bump_type(self) -> BumpType:
        """Analyze all commits and determine overall bump type needed."""
        commits = self.get_commits()
        if not commits:
            return BumpType.NONE
        
        max_bump = BumpType.NONE
        
        for commit in commits:
            bump = self.analyze_commit_message(commit)
            
            # Take the highest bump level needed
            if bump == BumpType.MAJOR:
                max_bump = BumpType.MAJOR
            elif bump == BumpType.MINOR and max_bump != BumpType.MAJOR:
                max_bump = BumpType.MINOR
            elif bump == BumpType.PATCH and max_bump == BumpType.NONE:
                max_bump = BumpType.PATCH
        
        return max_bump


class VersionManager:
    """Manages version updates in project files."""
    
    def __init__(self, info_plist_path: str = "Sources/WorkoutTracker/Info.plist"):
        self.info_plist_path = Path(info_plist_path)
    
    def get_current_version(self) -> SemanticVersion:
        """Get current version from Info.plist or git tags."""
        # Try Info.plist first
        if self.info_plist_path.exists():
            try:
                with open(self.info_plist_path, 'rb') as f:
                    plist = plistlib.load(f)
                
                version_string = plist.get('CFBundleShortVersionString', '0.0.0')
                
                # Ensure it's a valid semantic version
                if not re.match(r'^\d+\.\d+\.\d+', version_string):
                    # Convert simple versions like "1.0" to "1.0.0"
                    parts = version_string.split('.')
                    while len(parts) < 3:
                        parts.append('0')
                    version_string = '.'.join(parts[:3])
                
                return SemanticVersion(version_string)
            except Exception as e:
                print(f"Warning: Could not read version from Info.plist: {e}")
        
        # Fallback to git tags
        try:
            result = subprocess.run(['git', 'describe', '--tags', '--abbrev=0'], 
                                  capture_output=True, text=True, check=True)
            tag = result.stdout.strip()
            # Remove 'v' prefix if present
            version_string = tag[1:] if tag.startswith('v') else tag
            return SemanticVersion(version_string)
        except subprocess.CalledProcessError:
            # No tags exist, start from 0.0.0
            return SemanticVersion("0.0.0")
    
    def update_info_plist(self, new_version: SemanticVersion) -> bool:
        """Update version in Info.plist file."""
        if not self.info_plist_path.exists():
            print(f"Warning: Info.plist not found at {self.info_plist_path}")
            return False
        
        try:
            with open(self.info_plist_path, 'rb') as f:
                plist = plistlib.load(f)
            
            # Update version
            plist['CFBundleShortVersionString'] = str(new_version)
            
            # Optionally increment build number
            current_build = plist.get('CFBundleVersion', '1')
            try:
                new_build = str(int(current_build) + 1)
                plist['CFBundleVersion'] = new_build
            except ValueError:
                # Keep existing build number if it's not numeric
                pass
            
            with open(self.info_plist_path, 'wb') as f:
                plistlib.dump(plist, f)
            
            return True
        except Exception as e:
            print(f"Error updating Info.plist: {e}")
            return False


def get_last_version_tag() -> Optional[str]:
    """Get the last version tag from git."""
    try:
        result = subprocess.run(['git', 'describe', '--tags', '--abbrev=0'], 
                              capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_first_commit() -> Optional[str]:
    """Get the first commit hash."""
    try:
        result = subprocess.run(['git', 'rev-list', '--max-parents=0', 'HEAD'],
                              capture_output=True, text=True, check=True)
        return result.stdout.strip().split('\n')[0]
    except subprocess.CalledProcessError:
        return None


def main():
    parser = argparse.ArgumentParser(description='Automated semantic version bumping from conventional commits')
    parser.add_argument('--from', dest='from_ref', help='From tag/commit (default: last tag or first commit)')
    parser.add_argument('--to', dest='to_ref', default='HEAD', help='To tag/commit (default: HEAD)')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without making changes')
    parser.add_argument('--info-plist', default='Sources/WorkoutTracker/Info.plist', help='Path to Info.plist file')
    parser.add_argument('--output-json', help='Output version information as JSON to file')
    
    args = parser.parse_args()
    
    # Determine from_ref if not provided
    from_ref = args.from_ref
    if not from_ref:
        from_ref = get_last_version_tag()
        if not from_ref:
            from_ref = get_first_commit()
            if not from_ref:
                print("❌ Cannot determine starting point for version analysis")
                return 1
    
    try:
        # Get current version
        version_manager = VersionManager(args.info_plist)
        current_version = version_manager.get_current_version()
        
        # Analyze commits
        analyzer = CommitAnalyzer(from_ref, args.to_ref)
        bump_type = analyzer.determine_bump_type()
        
        # Calculate new version
        new_version = current_version.bump(bump_type)
        
        # Prepare results
        result = {
            'current_version': str(current_version),
            'new_version': str(new_version),
            'bump_type': bump_type.value,
            'from_ref': from_ref,
            'to_ref': args.to_ref,
            'commits_analyzed': len(analyzer.get_commits()),
            'version_changed': str(current_version) != str(new_version),
            'generated_at': datetime.now().isoformat()
        }
        
        # Display results
        print(f"📊 Version Analysis Results")
        print(f"==========================")
        print(f"Current Version: {current_version}")
        print(f"Commits Analyzed: {result['commits_analyzed']} (from {from_ref} to {args.to_ref})")
        print(f"Bump Type: {bump_type.value}")
        print(f"New Version: {new_version}")
        
        if not result['version_changed']:
            print("ℹ️ No version change needed")
            
        if args.dry_run:
            print(f"\n🔍 DRY RUN - Would update version to {new_version}")
            if result['version_changed']:
                print(f"  • Update {args.info_plist}")
                print(f"  • Increment build number")
        elif result['version_changed']:
            print(f"\n✏️ Updating version to {new_version}...")
            if version_manager.update_info_plist(new_version):
                print(f"✅ Version updated successfully in {args.info_plist}")
            else:
                print(f"❌ Failed to update version in {args.info_plist}")
                return 1
        
        # Output JSON if requested
        if args.output_json:
            output_path = Path(args.output_json)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(json.dumps(result, indent=2))
            print(f"📄 Version info saved to {args.output_json}")
        
        return 0
        
    except Exception as e:
        print(f"❌ Error during version analysis: {e}")
        return 1


if __name__ == '__main__':
    exit(main())