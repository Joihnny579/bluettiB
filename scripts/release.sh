#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <version> [--dry-run]"
  echo "Example: $0 0.1.7"
  echo "Example: $0 0.1.7 --dry-run"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

DRY_RUN=false
VERSION_ARG=""

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$VERSION_ARG" ]]; then
        VERSION_ARG="$arg"
      fi
      ;;
  esac
done

if [[ -z "$VERSION_ARG" ]]; then
  usage
  exit 1
fi

if [[ ! "$VERSION_ARG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version: $VERSION_ARG" >&2
  echo "Use semantic version format: X.Y.Z" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f VERSION ]]; then
  echo "Missing VERSION file in repo root" >&2
  exit 1
fi

printf '%s\n' "$VERSION_ARG" > VERSION
python3 scripts/sync_version.py

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: would commit and tag version $VERSION_ARG"
  git diff -- VERSION custom_components/bluetti_b/manifest.json README.md
  echo "Next commands:"
  echo "  git add VERSION custom_components/bluetti_b/manifest.json README.md"
  echo "  git commit -m \"Release $VERSION_ARG\""
  echo "  git tag -a v${VERSION_ARG} -m \"Release $VERSION_ARG\""
  echo "  git push origin ac200max"
  echo "  git push origin v${VERSION_ARG}"
  exit 0
fi

git add VERSION custom_components/bluetti_b/manifest.json README.md
if git diff --cached --quiet; then
  echo "No changes to release. VERSION already matches the repo state."
  exit 0
fi

git commit -m "Release $VERSION_ARG"
git tag -a "v${VERSION_ARG}" -m "Release $VERSION_ARG"

echo "Release $VERSION_ARG is prepared."
echo "Run these next:"
echo "  git push origin ac200max"
echo "  git push origin v${VERSION_ARG}"
