# Codex NVIDIA Dev Container Template

A reusable repository template for Python, PyTorch/CUDA, Hugging Face, and
Codex development on a local or Remote SSH Docker host.

## Included

- Parameterized PyTorch/CUDA base image
- Pinned Node and Codex CLI installation independent of the base image
- NVIDIA GPU selection with Docker and `CUDA_VISIBLE_DEVICES`
- Persistent Codex, Hugging Face, Torch, uv, and virtual-environment volumes
- Host-visible dataset, model, output, and experiment-run mounts
- Non-root development with host/container UID alignment
- Project-scoped Codex configuration and safety rules
- Repository-local Git hooks
- Minimal `uv` Python package and tests

## Prerequisites

Install Docker and VS Code with the Remote - SSH and Dev Containers
extensions. An NVIDIA host also needs a compatible driver and NVIDIA Container
Toolkit.

On the Docker host, verify GPU passthrough:

```bash
nvidia-smi
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
```

Docker access is privileged host access. Follow the host administrator's
rootless Docker or group-membership policy; do not make the Docker socket
world-writable.

## Create a project from this template

After creating a new repository from this template:

1. Replace `template_project` in `pyproject.toml`, `src/`, and tests.
2. Replace this README with the project's purpose and commands.
3. Replace the generic `AGENTS.md` architecture section.
4. Review `.codex/config.toml`, `.codex/rules/`, and `.githooks/`.
5. Select a tested PyTorch image and GPU allocation.
6. Change the named-volume prefix if multiple generated projects share a host.

Generated repositories are independent; later template changes do not update
them automatically.

## Select the base image

`.devcontainer/Dockerfile` accepts `BASE_IMAGE`, `NODE_IMAGE`,
`CODEX_VERSION`, and `UV_VERSION` build arguments. The committed defaults are
reviewed pins, not promises of the newest releases.

Use a PyTorch `runtime` image for prebuilt packages or `devel` when compiling
CUDA extensions. The final base must be Debian/Ubuntu compatible because the
system-package step uses `apt`.

## Select GPUs

The default exposes host GPU 0:

```jsonc
"runArgs": ["--gpus=device=0"],
"containerEnv": {
  "CUDA_VISIBLE_DEVICES": "0"
}
```

To expose host GPUs 2 and 3, use:

```jsonc
"runArgs": ["--gpus", "\"device=2,3\""],
"containerEnv": {
  "CUDA_VISIBLE_DEVICES": "0,1"
}
```

Docker exposes only the requested host devices. They are normally renumbered
inside the container, so host devices 2 and 3 become CUDA devices 0 and 1.
For all GPUs, use `"--gpus=all"` and omit `CUDA_VISIBLE_DEVICES` or select
in-container indexes. For CPU-only hosts, remove the GPU argument and
`CUDA_VISIBLE_DEVICES`, then select a CPU base image.

On shared or scheduled infrastructure, request GPUs through the scheduler.
`CUDA_VISIBLE_DEVICES` alone is not a resource or security boundary.

## Open locally or through Remote SSH

For a remote machine:

1. Connect using **Remote-SSH: Connect to Host...**.
2. Open the remote repository folder.
3. Run **Dev Containers: Reopen in Container**.
4. Run **Dev Containers: Rebuild Container** after image changes.

The repository, Docker data, named volumes, models, and datasets stay on the
remote host. The container entrypoint initializes volume ownership and then
drops privileges to `vscode`.

## Authenticate

Inside the container:

```bash
codex --version
codex login

hf auth login  # after adding a project dependency that provides the hf CLI
```

Codex state persists in a named volume mounted at `/home/vscode/.codex`.
Repository policy remains in `/workspace/.codex`. Hugging Face data persists
under `HF_HOME` in a private named volume.

Never put tokens in the Dockerfile, build arguments, `devcontainer.json`, Git,
or a committed environment file.

## Develop

```bash
uv sync --frozen
uv run python -m template_project
uv run python -m unittest discover -s tests
uv run python -m compileall src
```

Add dependencies with `uv add PACKAGE`; do not use `pip install` or
`uv pip install` for project dependencies.

## Validate the environment

```bash
id
test -w /workspace
test -w /home/vscode/.codex
test -w "$HF_HOME"

codex --version
node --version

uv run python - <<'PY'
import os
import torch

print("torch:", torch.__version__)
print("CUDA_VISIBLE_DEVICES:", os.environ.get("CUDA_VISIBLE_DEVICES"))
print("CUDA available:", torch.cuda.is_available())
print("visible device count:", torch.cuda.device_count())
if torch.cuda.is_available():
    print("device 0:", torch.cuda.get_device_name(0))
PY
```

If the host can run `nvidia-smi` but PyTorch cannot see CUDA, verify Docker's
`--gpus all` smoke test, NVIDIA Container Toolkit configuration, the image's
CUDA variant, and host-driver compatibility.

## Persistent data

Named volumes survive container rebuilds and are intentionally not part of the
repository. They are not backups. Keep unique trained weights in an explicitly
backed-up host or object-storage location.

Do not remove Docker volumes or run broad Docker cleanup commands without
reviewing which projects and caches they affect.

### Mounted ML storage

Before container creation, `initializeCommand` creates this layout on the
Docker host:

```text
~/ml-storage/
├── datasets/
├── models/
├── outputs/
└── runs/
```

All four directories are writable bind mounts so downloads and training
artifacts remain visible outside the container. They are available inside as
`DATASETS_DIR`, `MODELS_DIR`, `OUTPUTS_DIR`, and `RUNS_DIR`. They are independent
of the Hugging Face cache, which remains in its existing named volume under
`/home/vscode/.cache/huggingface`.

The directories are created as the local or Remote SSH user, and
`updateRemoteUserUID` aligns the container user with that host ownership. Do
not add these external bind mounts to the entrypoint's `chown` loop. On a
multi-user host, replace this single-user layout with administrator-managed
group permissions and add the shared numeric GID through Docker.

### Agent worktrees

`/workspace/.worktrees` is runtime storage for isolated Git worktrees used by
Codex or other agent workflows. It is ignored by Git, mounted from a persistent
Docker volume, and included as a writable root in `.codex/config.toml`. Do not
commit worktree contents or create a nested repository there manually.

Each generated project must give the volume a unique name. Change this entry in
`.devcontainer/devcontainer.json`:

```jsonc
"source=codex-nvidia-template-worktrees,target=/workspace/.worktrees,type=volume"
```

For example:

```jsonc
"source=my-project-worktrees,target=/workspace/.worktrees,type=volume"
```

Sharing one worktree volume between unrelated repositories is unsafe because
Git worktree metadata points back to a specific main checkout. If the project
will not use Git worktrees or modifying subagents, remove the worktree mount,
the `.codex/config.toml` writable-root entry, and the `.worktrees/` ignore rule.
