#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository; skipping branch check."
  exit 0
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"

case "$BRANCH" in
  main|master)
    echo "Refusing to continue on protected branch: $BRANCH" >&2
    exit 1
    ;;
  *)
    echo "Branch check passed: $BRANCH"
    ;;
esac
