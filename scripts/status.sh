#!/bin/bash

# Version Status Checker for Dogtor App
# This script shows the current version status across all components

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC_FILE="$PROJECT_ROOT/frontend/superb_flutter_app/pubspec.yaml"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🐶 Dogtor App Version Status${NC}"
echo "================================="

# Get Flutter app version
if [[ -f "$PUBSPEC_FILE" ]]; then
    APP_VERSION=$(grep "^version:" "$PUBSPEC_FILE" | sed 's/version: //' | tr -d ' ')
    echo -e "${GREEN}📱 Flutter App:${NC} $APP_VERSION"
else
    echo -e "${YELLOW}📱 Flutter App: pubspec.yaml not found${NC}"
fi

# Check git status
if git rev-parse --git-dir > /dev/null 2>&1; then
    CURRENT_BRANCH=$(git branch --show-current)
    LAST_COMMIT=$(git log -1 --pretty=format:"%h %s (%cr)")
    UNCOMMITTED_CHANGES=$(git status --porcelain | wc -l | tr -d ' ')
    
    echo -e "${GREEN}🌿 Git Branch:${NC} $CURRENT_BRANCH"
    echo -e "${GREEN}📝 Last Commit:${NC} $LAST_COMMIT"
    
    if [[ "$UNCOMMITTED_CHANGES" -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Uncommitted Changes:${NC} $UNCOMMITTED_CHANGES files"
    else
        echo -e "${GREEN}✅ Working Directory:${NC} Clean"
    fi
    
    # Check for tags
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "No tags")
    echo -e "${GREEN}🏷️  Latest Tag:${NC} $LATEST_TAG"
else
    echo -e "${YELLOW}🌿 Git: Not in a git repository${NC}"
fi

# Check backend status
BACKEND_MAIN="$PROJECT_ROOT/backend/app/main.py"
if [[ -f "$BACKEND_MAIN" ]]; then
    echo -e "${GREEN}⚡ Backend:${NC} Found (FastAPI)"
else
    echo -e "${YELLOW}⚡ Backend: main.py not found${NC}"
fi

# Check for environment files
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    echo -e "${GREEN}🔧 Environment:${NC} .env file exists"
else
    echo -e "${YELLOW}🔧 Environment: .env file missing${NC}"
fi

# Check documentation
DOC_FILES=(
    "CHANGELOG.md"
    "docs/RELEASE_CHECKLIST.md"
    "docs/VERSION_INFO.md"
)

echo -e "${GREEN}📚 Documentation:${NC}"
for doc in "${DOC_FILES[@]}"; do
    if [[ -f "$PROJECT_ROOT/$doc" ]]; then
        echo -e "   ✅ $doc"
    else
        echo -e "   ❌ $doc"
    fi
done

echo ""
echo -e "${BLUE}🚀 Quick Commands:${NC}"
echo "  ./scripts/version.sh current    # Show current version"
echo "  ./scripts/version.sh patch      # Bump patch version"
echo "  git tag -l                      # List all tags"
echo "  flutter --version               # Check Flutter version"

echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "  1. Review CHANGELOG.md for completeness"
echo "  2. Test app on both iOS and Android"
echo "  3. Run './scripts/version.sh patch' before release"
echo "  4. Follow docs/RELEASE_CHECKLIST.md for store submission"
