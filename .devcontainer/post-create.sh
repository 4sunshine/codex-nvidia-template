#!/usr/bin/env bash
set -euo pipefail

if [[ "${TEMPLATE_DEVCONTAINER:-}" != "1" || "$(id -u)" -eq 0 ]]; then
  echo "post-create.sh must run as the non-root Dev Container user" >&2
  exit 1
fi

cd /workspace

git config --local core.hooksPath .githooks
echo "Dependencies and repository-local Git hooks are ready."
