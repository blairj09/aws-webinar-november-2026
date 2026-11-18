#!/usr/bin/env bash
# Render the public build and push it to the gh-pages branch.
# Only the rendered site is pushed; the source (with speaker notes) stays local.
# Stop any running `quarto preview` in this folder first.
set -euo pipefail

cd "$(dirname "$0")"
remote_url="$(git remote get-url origin)"

rm -rf _site
QUARTO_PROFILE=publish quarto render

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Start from the existing gh-pages history if there is one, so pushes fast-forward.
if git ls-remote --exit-code --heads "$remote_url" gh-pages >/dev/null 2>&1; then
  git clone -q --branch gh-pages --single-branch "$remote_url" "$tmp"
  find "$tmp" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
else
  git -C "$tmp" init -q -b gh-pages
fi

cp -R _site/. "$tmp"
touch "$tmp/.nojekyll"

git -C "$tmp" add -A
if git -C "$tmp" diff --cached --quiet; then
  echo "No changes to publish."
  exit 0
fi
git -C "$tmp" commit -q -m "Publish site $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git -C "$tmp" push -q "$remote_url" gh-pages:gh-pages

echo "Published to gh-pages."
