#!/usr/bin/env bash
# Release helper: bump version, tag, and (optionally) push to trigger CI build + release.
# Usage: ./release.sh [major|minor|patch] [--push]
# versionName = semantic (x.y.z); versionCode = monotonically increasing commit count.
set -euo pipefail
cd "$(dirname "$0")"

PART="${1:-patch}"
PUSH=false
for a in "$@"; do [ "$a" = "--push" ] && PUSH=true; done

VER=$(sed -nE 's/^version: ([0-9]+\.[0-9]+\.[0-9]+)\+[0-9]+$/\1/p' pubspec.yaml)
[ -n "$VER" ] || { echo "no semantic version in pubspec.yaml"; exit 1; }

IFS=. read -r MA MI PA <<< "$VER"
case "$PART" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  patch) PA=$((PA+1)) ;;
  *) echo "usage: $0 [major|minor|patch] [--push]"; exit 1 ;;
esac
NV="$MA.$MI.$PA"
CODE=$(( $(git rev-list --count HEAD) + 1 ))

echo "-> $NV (versionCode $CODE)"
sed -i -E "s/^version: .*/version: $NV+$CODE/" pubspec.yaml
git add pubspec.yaml
git -c user.email="j03randall@gmail.com" -c user.name="Flexingg" commit -qm "chore: release v$NV"
git tag -a "v$NV" -m "HabitCraft v$NV"

if [ "$PUSH" = true ]; then
  git push origin HEAD
  git push origin "v$NV"
  echo "pushed — GitHub Actions is building and attaching the APK to the v$NV release."
else
  echo "Ready. Push to trigger CI:  git push && git push origin v$NV"
fi
