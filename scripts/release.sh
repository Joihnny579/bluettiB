#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <version> [--dry-run] [--publish]"
  echo "Example: $0 0.1.7"
  echo "Example: $0 0.1.7 --dry-run"
  echo "Example: $0 0.1.7 --publish"
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

DRY_RUN=false
PUBLISH=false
VERSION_ARG=""

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    --publish)
      PUBLISH=true
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
  if [[ "$PUBLISH" == true ]]; then
    echo "  gh release create v${VERSION_ARG} --title v${VERSION_ARG} --generate-notes --latest"
  fi
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

if [[ "$PUBLISH" == true ]]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found. Push and create the Release manually:" >&2
    echo "  git push origin $(git rev-parse --abbrev-ref HEAD)" >&2
    echo "  git push origin v${VERSION_ARG}" >&2
    echo "  gh release create v${VERSION_ARG} --title v${VERSION_ARG} --generate-notes --latest" >&2
    exit 1
  fi
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  git push origin "$BRANCH"
  git push origin "v${VERSION_ARG}"
  NOTES_FILE="$(mktemp)"
  if [[ -f CHANGELOG.md ]]; then
    # extract the section for this version (up to the next '## ' heading)
    awk -v v="## ${VERSION_ARG}" '
      $0==v {f=1; next}
      /^## / {f=0}
      f {print}
    ' CHANGELOG.md > "$NOTES_FILE"
  fi
  if [[ -s "$NOTES_FILE" ]]; then
    gh release create "v${VERSION_ARG}" --title "v${VERSION_ARG}" \
      --notes-file "$NOTES_FILE" --latest
  else
    gh release create "v${VERSION_ARG}" --title "v${VERSION_ARG}" \
      --generate-notes --latest
  fi
  rm -f "$NOTES_FILE"
  echo "Published GitHub Release v${VERSION_ARG}"
fi
