#!/bin/bash

# Version Management Script for Dogtor App
# Usage: ./scripts/version.sh [major|minor|patch|build]

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_FILE="$PROJECT_ROOT/frontend/superb_flutter_app/pubspec.yaml"
CHANGELOG_FILE="$PROJECT_ROOT/CHANGELOG.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_colored() {
    echo -e "${1}${2}${NC}"
}

# Function to get current version from pubspec.yaml
get_current_version() {
    grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | tr -d ' '
}

# Function to increment version
increment_version() {
    local version_type=$1
    local current_version=$(get_current_version)
    local version_part=$(echo "$current_version" | cut -d'+' -f1)
    local build_part=$(echo "$current_version" | cut -d'+' -f2)
    
    IFS='.' read -ra VERSION_ARRAY <<< "$version_part"
    local major=${VERSION_ARRAY[0]}
    local minor=${VERSION_ARRAY[1]}
    local patch=${VERSION_ARRAY[2]}
    
    case $version_type in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            build_part=$((build_part + 1))
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            build_part=$((build_part + 1))
            ;;
        "patch")
            patch=$((patch + 1))
            build_part=$((build_part + 1))
            ;;
        "build")
            build_part=$((build_part + 1))
            ;;
        *)
            print_colored $RED "Invalid version type. Use: major, minor, patch, or build"
            exit 1
            ;;
    esac
    
    echo "${major}.${minor}.${patch}+${build_part}"
}

# Function to update pubspec.yaml
update_pubspec() {
    local new_version=$1
    local temp_file=$(mktemp)
    
    # Use sed to replace the version line
    sed "s/^version: .*/version: $new_version/" "$PUBSPEC_FILE" > "$temp_file"
    mv "$temp_file" "$PUBSPEC_FILE"
    
    print_colored $GREEN "✅ Updated pubspec.yaml to version $new_version"
}

# Function to update CHANGELOG.md
update_changelog() {
    local new_version=$1
    local version_part=$(echo "$new_version" | cut -d'+' -f1)
    local today=$(date +%Y-%m-%d)
    
    # Create a temporary file with the new changelog entry
    local temp_file=$(mktemp)
    
    # Read the changelog and insert new version after [Unreleased]
    while IFS= read -r line; do
        echo "$line" >> "$temp_file"
        if [[ "$line" == "## [Unreleased]" ]]; then
            echo "" >> "$temp_file"
            echo "### Added" >> "$temp_file"
            echo "- " >> "$temp_file"
            echo "" >> "$temp_file"
            echo "### Changed" >> "$temp_file"
            echo "- " >> "$temp_file"
            echo "" >> "$temp_file"
            echo "### Fixed" >> "$temp_file"
            echo "- " >> "$temp_file"
            echo "" >> "$temp_file"
            echo "## [$version_part] - $today" >> "$temp_file"
            echo "" >> "$temp_file"
            echo "### Added" >> "$temp_file"
            echo "- Version $version_part release" >> "$temp_file"
            echo "" >> "$temp_file"
        fi
    done < "$CHANGELOG_FILE"
    
    mv "$temp_file" "$CHANGELOG_FILE"
    print_colored $GREEN "✅ Updated CHANGELOG.md with version $version_part"
}

# Function to create git tag
create_git_tag() {
    local new_version=$1
    local version_part=$(echo "$new_version" | cut -d'+' -f1)
    local tag_name="v$version_part"
    
    print_colored $BLUE "Creating git tag: $tag_name"
    
    # Check if tag already exists
    if git tag -l | grep -q "^$tag_name$"; then
        print_colored $YELLOW "⚠️  Tag $tag_name already exists"
        return
    fi
    
    # Create the tag
    git add "$PUBSPEC_FILE" "$CHANGELOG_FILE"
    git commit -m "chore: bump version to $version_part"
    git tag -a "$tag_name" -m "Release version $version_part"
    
    print_colored $GREEN "✅ Created git tag: $tag_name"
    print_colored $BLUE "To push the tag, run: git push origin $tag_name"
}

# Function to show current version
show_current_version() {
    local current_version=$(get_current_version)
    print_colored $BLUE "Current version: $current_version"
}

# Function to validate environment
validate_environment() {
    if [[ ! -f "$PUBSPEC_FILE" ]]; then
        print_colored $RED "❌ pubspec.yaml not found at $PUBSPEC_FILE"
        exit 1
    fi
    
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        print_colored $RED "❌ CHANGELOG.md not found at $CHANGELOG_FILE"
        exit 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_colored $RED "❌ Not in a git repository"
        exit 1
    fi
}

# Function to show help
show_help() {
    cat << EOF
Dogtor App Version Management Script

Usage: $0 [command] [options]

Commands:
  major     Increment major version (breaking changes)
  minor     Increment minor version (new features)
  patch     Increment patch version (bug fixes)
  build     Increment build number only
  current   Show current version
  help      Show this help message

Examples:
  $0 patch          # 0.1.0+1 -> 0.1.1+2
  $0 minor          # 0.1.1+2 -> 0.2.0+3
  $0 major          # 0.2.0+3 -> 1.0.0+4
  $0 build          # 1.0.0+4 -> 1.0.0+5
  $0 current        # Show current version

Options:
  --no-tag          Don't create git tag
  --no-changelog    Don't update CHANGELOG.md

The script will:
1. Update version in pubspec.yaml
2. Update CHANGELOG.md (unless --no-changelog)
3. Create git commit and tag (unless --no-tag)

For App Store releases:
- Use 'major' for breaking changes
- Use 'minor' for new features
- Use 'patch' for bug fixes
- Use 'build' for development builds
EOF
}

# Main execution
main() {
    local command=${1:-help}
    local no_tag=false
    local no_changelog=false
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-tag)
                no_tag=true
                shift
                ;;
            --no-changelog)
                no_changelog=true
                shift
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            current)
                validate_environment
                show_current_version
                exit 0
                ;;
            major|minor|patch|build)
                command=$1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ "$command" == "help" ]]; then
        show_help
        exit 0
    fi
    
    # Validate environment
    validate_environment
    
    # Show current version
    show_current_version
    
    # Calculate new version
    local new_version=$(increment_version "$command")
    local version_part=$(echo "$new_version" | cut -d'+' -f1)
    
    print_colored $YELLOW "🚀 Bumping version to: $new_version"
    
    # Ask for confirmation
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_colored $YELLOW "Aborted."
        exit 0
    fi
    
    # Update files
    update_pubspec "$new_version"
    
    if [[ "$no_changelog" == false ]]; then
        update_changelog "$new_version"
    fi
    
    if [[ "$no_tag" == false ]]; then
        create_git_tag "$new_version"
    fi
    
    print_colored $GREEN "🎉 Version bump completed!"
    print_colored $BLUE "Next steps:"
    print_colored $BLUE "1. Review the changes in CHANGELOG.md"
    print_colored $BLUE "2. Test the app thoroughly"
    print_colored $BLUE "3. Push to repository: git push && git push --tags"
    print_colored $BLUE "4. Deploy to app stores"
}

# Run the script
main "$@"
