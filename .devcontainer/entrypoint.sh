#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "template-entrypoint must start as root" >&2
  exit 1
fi

for directory in \
  /home/vscode/.codex \
  /home/vscode/.cache/huggingface \
  /home/vscode/.cache/torch \
  /home/vscode/.cache/uv \
  /workspace/.venv \
  /workspace/.worktrees; do
  if [[ ! -d "${directory}" ]]; then
    echo "required mounted directory is missing: ${directory}" >&2
    exit 1
  fi
  chown root:root "${directory}"
  chmod 0755 "${directory}"
  chown vscode:vscode "${directory}"
done

chmod 0700 /home/vscode/.codex

export HOME=/home/vscode
export USER=vscode
export LOGNAME=vscode

exec setpriv \
  --reuid=vscode \
  --regid=vscode \
  --init-groups \
  --no-new-privs \
  "$@"

