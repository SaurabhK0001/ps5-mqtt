#!/usr/bin/env bash
# Rebuild the self-contained add-on folder (add-ons/ps5-mqtt) that Home Assistant
# builds locally. Mirrors upstream's release.yml "Assemble add-on Docker context"
# step, so the fork needs no prebuilt image from ghcr.io/funkeyflo.
#
# Run after merging upstream changes, then bump `version:` in
# add-ons/ps5-mqtt/config.yaml — HA only rebuilds when the version changes.
# Needs Docker; builds with the Node version upstream pins (package.json engines).
set -euo pipefail
cd "$(dirname "$0")/.."

NODE_IMAGE="node:$(node -p "require('./package.json').engines.node" 2>/dev/null || echo 24.16.0)"
ADDON=add-ons/ps5-mqtt
UID_GID="$(id -u):$(id -g)"

docker run --rm -v "$PWD":/src -w /src "$NODE_IMAGE" bash -c "
  set -e
  corepack enable
  yes | yarn install --immutable
  yarn build
  PREPARE_ONLY=1 SKIP_BUILD=1 yarn workspace @ps5-mqtt/server package
  cd ps5-mqtt/server/.packaged/server
  npm install --package-lock-only --omit=dev --omit=optional --no-audit --no-fund
  chown -R $UID_GID /src
"

rm -rf "$ADDON/ps5-mqtt"
mkdir -p "$ADDON/ps5-mqtt/server"
cp -R ps5-mqtt/server/.packaged "$ADDON/ps5-mqtt/server/.packaged"
cp add-ons/common/Dockerfile add-ons/common/build.yaml add-ons/common/.dockerignore add-ons/common/run.sh "$ADDON/"
cp README.md "$ADDON/README.md"
cp docs/DOCS.md "$ADDON/DOCS.md"
rm -rf ps5-mqtt/server/.packaged

echo "Assembled $ADDON — now bump its config.yaml version and commit."
