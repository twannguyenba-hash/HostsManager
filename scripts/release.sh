#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Usage: ./scripts/release.sh <version>"
    echo "Example: ./scripts/release.sh 1.2.0"
    exit 1
fi

VERSION=$1

echo "=== Releasing HostsManager v${VERSION} ==="

# Update version in project.yml
sed -i '' "s/MARKETING_VERSION: .*/MARKETING_VERSION: \"${VERSION}\"/" project.yml

# Update version in Makefile
sed -i '' "s/^VERSION = .*/VERSION = ${VERSION}/" Makefile

# Verify versions were updated
if ! grep -q "MARKETING_VERSION: \"${VERSION}\"" project.yml; then
    echo "ERROR: Failed to update version in project.yml"
    exit 1
fi

if ! grep -q "^VERSION = ${VERSION}" Makefile; then
    echo "ERROR: Failed to update version in Makefile"
    exit 1
fi

echo "✓ Updated project.yml and Makefile to v${VERSION}"

# Commit only version files
git add project.yml Makefile
git commit -m "chore: release v${VERSION}"
git tag -a "v${VERSION}" -m "Release v${VERSION}"

echo "✓ Created commit and tag v${VERSION}"

# Push
git push origin main --tags

echo ""
echo "=== Done! ==="
echo "GitHub Actions will:"
echo "  1. Build universal binary"
echo "  2. Create GitHub Release with ZIP + DMG"
echo "  3. Update Homebrew tap automatically"
echo ""
echo "Track progress: gh run list --limit 1"
