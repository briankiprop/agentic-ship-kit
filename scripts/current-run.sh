#!/usr/bin/env bash
set -euo pipefail

if [ -f .agent-runs/latest-run.txt ]; then
  cat .agent-runs/latest-run.txt
  exit 0
fi

latest="$(find .agent-runs -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n 1 || true)"
if [ -n "$latest" ]; then
  printf '%s\n' "$latest"
else
  echo "No run folder found. Start with: scripts/create-run.sh \"your task\"" >&2
  exit 1
fi
