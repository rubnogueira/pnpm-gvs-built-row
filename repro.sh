#!/usr/bin/env bash
# See README.md.
set -eu
cd "$(dirname "$0")"
rm -rf store cache project-*/node_modules project-*/pnpm-lock.yaml

for project in project-a project-b; do
  (cd "$project" && pnpm install --reporter=silent)
  if ls "$project"/node_modules/node-expat/build/Release/*.node > /dev/null 2>&1; then
    echo "$project: built"
  else
    echo "$project: NOT BUILT"
  fi
done
