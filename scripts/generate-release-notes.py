#!/usr/bin/env python3
"""
Simple release notes generator from conventional commits.
Follows development philosophy: simplicity and clarity over premature optimization.
"""

import re
import subprocess
import json
import argparse
from datetime import datetime, timezone
from typing import Dict, List, Tuple, Optional
from pathlib import Path


class ReleaseNotesGenerator:
    """Generate release notes from conventional commit messages."""
    
    CATEGORIES = {
        'feat': '🚀 New Features',
        'fix': '🐛 Bug Fixes', 
        'docs': '📚 Documentation',
        'style': '💅 Code Style',
        'refactor': '♻️ Code Refactoring',
        'test': '🧪 Tests',
        'chore': '🔧 Maintenance',
        'ci': '👷 CI/CD',
        'perf': '⚡ Performance',
        'build': '📦 Build System',
        'revert': '⏪ Reverts'
    }
    
    def __init__(self, from_ref: str, to_ref: str = 'HEAD'):
        self.from_ref = from_ref
        self.to_ref = to_ref
        self.commits = []
        self.categorized_commits: Dict[str, List[str]] = {}
        self.breaking_changes: List[str] = []
        
    def get_commits(self) -> List[Tuple[str, str]]:
        """Get commit messages between references."""
        try:
            cmd = ['git', 'log', f'{self.from_ref}..{self.to_ref}', '--pretty=format:%H|%s']
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            commits = []
            for line in result.stdout.strip().split('\n'):
                if line.strip():
                    hash_msg = line.split('|', 1)
                    if len(hash_msg) == 2:
                        commits.append((hash_msg[0], hash_msg[1]))
            return commits
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to get git commits: {e}")
    
    def parse_conventional_commit(self, message: str) -> Tuple[str, str, bool]:
        """Parse conventional commit message format."""
        # Pattern: type(scope)!: description
        pattern = r'^([a-zA-Z]+)(\([^)]*\))?(!)?:\s*(.*)$'
        match = re.match(pattern, message)
        
        if match:
            commit_type = match.group(1)
            scope = match.group(2) or ''
            breaking = match.group(3) == '!'
            description = match.group(4)
            
            # Format scope for display
            scope_display = scope[1:-1] + ': ' if scope else ''
            formatted = f"{scope_display}{description}"
            
            return commit_type, formatted, breaking
        
        # Non-conventional commit
        return 'other', message, False
    
    def categorize_commits(self) -> None:
        """Categorize commits by type."""
        self.commits = self.get_commits()
        
        for hash_val, message in self.commits:
            commit_type, formatted_msg, is_breaking = self.parse_conventional_commit(message)
            
            # Track breaking changes
            if is_breaking or 'BREAKING CHANGE' in message:
                self.breaking_changes.append(formatted_msg)
            
            # Categorize commit
            if commit_type not in self.categorized_commits:
                self.categorized_commits[commit_type] = []
            self.categorized_commits[commit_type].append(formatted_msg)
    
    def generate_markdown(self, version: Optional[str] = None, github_format: bool = False) -> str:
        """Generate markdown release notes."""
        self.categorize_commits()
        
        lines = []
        
        # Title
        if not github_format:
            if version:
                lines.append(f"# Release Notes - v{version}")
            else:
                lines.append(f"# Release Notes - {datetime.now().strftime('%Y-%m-%d')}")
            lines.append("")
            lines.append(f"_Generated from commits {self.from_ref}..{self.to_ref}_")
            lines.append("")
        
        # Summary
        total_commits = len(self.commits)
        category_count = len(self.categorized_commits)
        
        if not github_format:
            lines.append("## Summary")
            lines.append("")
            lines.append(f"**{total_commits} commits** across {category_count} categories:")
            lines.append("")
            
            for commit_type in self.CATEGORIES:
                if commit_type in self.categorized_commits:
                    count = len(self.categorized_commits[commit_type])
                    lines.append(f"- {self.CATEGORIES[commit_type]}: {count} commits")
            
            if 'other' in self.categorized_commits:
                count = len(self.categorized_commits['other'])
                lines.append(f"- 📋 Other Changes: {count} commits")
            lines.append("")
        
        # Breaking changes
        if self.breaking_changes:
            lines.append("## ⚠️ BREAKING CHANGES")
            lines.append("")
            for change in self.breaking_changes:
                lines.append(f"- {change}")
            lines.append("")
        
        # Changes by category
        lines.append("## Changes")
        lines.append("")
        
        # Order categories by importance
        category_order = ['feat', 'fix', 'perf', 'docs', 'refactor', 'test', 'ci', 'build', 'chore', 'style', 'revert']
        
        for commit_type in category_order:
            if commit_type in self.categorized_commits:
                category_name = self.CATEGORIES[commit_type]
                lines.append(f"### {category_name}")
                lines.append("")
                
                for commit_msg in self.categorized_commits[commit_type]:
                    lines.append(f"- {commit_msg}")
                lines.append("")
        
        # Other changes
        if 'other' in self.categorized_commits:
            lines.append("### 📋 Other Changes")
            lines.append("")
            for commit_msg in self.categorized_commits['other']:
                lines.append(f"- {commit_msg}")
            lines.append("")
        
        # Footer
        if not github_format:
            lines.append("---")
            lines.append("")
            lines.append(f"_Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')}_")
            if version:
                lines.append(f"_Version: {version}_")
        
        return '\n'.join(lines)
    
    def generate_summary_json(self, version: Optional[str] = None) -> Dict:
        """Generate JSON summary for CI/automation."""
        return {
            'version': version or 'unknown',
            'from_ref': self.from_ref,
            'to_ref': self.to_ref,
            'total_commits': len(self.commits),
            'categories': list(self.categorized_commits.keys()),
            'commit_counts': {k: len(v) for k, v in self.categorized_commits.items()},
            'breaking_changes': len(self.breaking_changes),
            'generated_at': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
        }


def get_last_tag() -> Optional[str]:
    """Get the last git tag, or None if no tags exist."""
    try:
        result = subprocess.run(['git', 'describe', '--tags', '--abbrev=0'], 
                              capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_first_commit() -> Optional[str]:
    """Get the first commit in the repository."""
    try:
        result = subprocess.run(['git', 'rev-list', '--max-parents=0', 'HEAD'],
                              capture_output=True, text=True, check=True)
        return result.stdout.strip().split('\n')[0]
    except subprocess.CalledProcessError:
        return None


def main():
    parser = argparse.ArgumentParser(description='Generate release notes from conventional commits')
    parser.add_argument('--from', dest='from_ref', help='From tag/commit (default: last tag or first commit)')
    parser.add_argument('--to', dest='to_ref', default='HEAD', help='To tag/commit (default: HEAD)')
    parser.add_argument('--version', help='Version number for release')
    parser.add_argument('--output', '-o', default='release-notes/release-notes.md', help='Output file')
    parser.add_argument('--github-format', action='store_true', help='Format for GitHub releases')
    
    args = parser.parse_args()
    
    # Determine from_ref if not provided
    from_ref = args.from_ref
    if not from_ref:
        from_ref = get_last_tag()
        if not from_ref:
            from_ref = get_first_commit()
            if not from_ref:
                print("❌ Cannot determine starting point for release notes")
                return 1
    
    try:
        # Create output directory
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Generate release notes
        generator = ReleaseNotesGenerator(from_ref, args.to_ref)
        markdown = generator.generate_markdown(args.version, args.github_format)
        
        # Write markdown file
        output_path.write_text(markdown)
        
        # Write JSON summary
        summary_path = output_path.parent / 'release-summary.json'
        summary = generator.generate_summary_json(args.version)
        summary_path.write_text(json.dumps(summary, indent=2))
        
        # Display summary
        print(f"✅ Release notes generated successfully!")
        print(f"📄 Output: {output_path}")
        print(f"📊 Summary: {summary_path}")
        print(f"📈 Total commits: {summary['total_commits']}")
        print(f"📋 Categories: {len(summary['categories'])}")
        if summary['breaking_changes'] > 0:
            print(f"⚠️ Breaking changes: {summary['breaking_changes']}")
        
        return 0
        
    except Exception as e:
        print(f"❌ Error generating release notes: {e}")
        return 1


if __name__ == '__main__':
    exit(main())