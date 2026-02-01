#!/bin/bash
set -euo pipefail

BUILD_DIR="dist"
SOURCE_DIRECTORY_DEPLOY_GH="${HOME}/temp-gh-deploy-src"
CLONED_DIRECTORY_DEPLOY_GH="${HOME}/temp-gh-deploy-cloned"

echo "#############################################"
echo "######### making directories"
echo "######### $SOURCE_DIRECTORY_DEPLOY_GH"
echo "######### $CLONED_DIRECTORY_DEPLOY_GH"
echo "#############################################"

rm -rf "$SOURCE_DIRECTORY_DEPLOY_GH" "$CLONED_DIRECTORY_DEPLOY_GH"
mkdir -p "$SOURCE_DIRECTORY_DEPLOY_GH" "$CLONED_DIRECTORY_DEPLOY_GH"

echo "#############################################"
echo "######### Setting env vars"
echo "#############################################"

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required (e.g. owner/repo)}"

OWNER="${GITHUB_REPOSITORY%%/*}"
REPONAME="${GITHUB_REPOSITORY##*/}"
GHIO="${OWNER}.github.io"

if [[ "$REPONAME" == "$GHIO" ]]; then
  REMOTE_BRANCH="master"
else
  REMOTE_BRANCH="gh-pages"
fi

# Repo URL: use token if present (CI), otherwise use plain https (local git credential helper can handle auth)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  REMOTE_REPO="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
else
  REMOTE_REPO="https://github.com/${GITHUB_REPOSITORY}.git"
fi

echo "Repo: $GITHUB_REPOSITORY"
echo "Branch to deploy: $REMOTE_BRANCH"
echo "Build dir: $BUILD_DIR"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "ERROR: Build directory '$BUILD_DIR' does not exist. Did the build run?"
  exit 1
fi

echo "#############################################"
echo "######### Copy build output"
echo "#############################################"
cp -R "$BUILD_DIR" "$SOURCE_DIRECTORY_DEPLOY_GH/"

echo "#############################################"
echo "######### Clone or init deploy branch"
echo "#############################################"

# Try to clone the branch; if it doesn't exist, init an orphan branch
if git ls-remote --exit-code --heads "$REMOTE_REPO" "$REMOTE_BRANCH" >/dev/null 2>&1; then
  git clone --single-branch --branch="$REMOTE_BRANCH" "$REMOTE_REPO" "$CLONED_DIRECTORY_DEPLOY_GH"
else
  git clone "$REMOTE_REPO" "$CLONED_DIRECTORY_DEPLOY_GH"
  cd "$CLONED_DIRECTORY_DEPLOY_GH"
  git checkout --orphan "$REMOTE_BRANCH"
  git rm -rf . >/dev/null 2>&1 || true
fi

echo "#############################################"
echo "######### Replace contents"
echo "#############################################"

cd "$CLONED_DIRECTORY_DEPLOY_GH"
git rm -rf . >/dev/null 2>&1 || true
git clean -fdx

cp -R "${SOURCE_DIRECTORY_DEPLOY_GH}/${BUILD_DIR}" "./${BUILD_DIR}"

cd "$CLONED_DIRECTORY_DEPLOY_GH"
git config user.name "${GITHUB_ACTOR:-github-actions}"
git config user.email "${GITHUB_ACTOR:-github-actions}@users.noreply.github.com"

echo "#############################################"
echo "######### Commit and push"
echo "#############################################"

# Tiny change to ensure Pages rebuild if needed
date -u +"%Y-%m-%dT%H:%M:%SZ" > forcebuild.date

git add -A

if git diff --cached --quiet; then
  echo "No changes to deploy. Exiting cleanly."
  exit 0
fi

git commit -m "Deploy to GitHub Pages"
git push "$REMOTE_REPO" "$REMOTE_BRANCH:$REMOTE_BRANCH"