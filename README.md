# NVIDIA ML Dev Container Template

Fork this repository to start a reproducible Python, PyTorch/CUDA, `uv`, and
VS Code development environment. The source code is bind-mounted into the
container; datasets, models, outputs, caches, and the virtual environment
survive container rebuilds.

## 1. Fork and rename the repository

1. Open this repository on GitHub and select **Fork**.
2. In the fork, open **Settings → General → Repository name**, enter your
   project name, and select **Rename**.
3. Clone the renamed fork over HTTPS:

```bash
git clone https://github.com/YOUR_ORG/my-ml-project.git
cd my-ml-project
```

Rename the starter Python package and its references. Use a hyphenated GitHub
name and an underscore-separated Python import name:

```bash
PROJECT_SLUG=my-ml-project
PYTHON_PACKAGE=my_ml_project

mv src/template_project "src/${PYTHON_PACKAGE}"

rg -l 'template_project|template-project' pyproject.toml src tests \
  | xargs sed -i \
      -e "s/template_project/${PYTHON_PACKAGE}/g" \
      -e "s/template-project/${PROJECT_SLUG}/g"

# Named Docker volumes must be unique for every fork on the same host.
sed -i "s/codex-nvidia-template/${PROJECT_SLUG}/g" \
  .devcontainer/devcontainer.json
```

Replace the template text in `PROJECT.md` and `README.md` with the new
project's objective before inviting contributors.

## 2. Configure the development container

The committed configuration works with one NVIDIA GPU and the pinned PyTorch
2.10/CUDA 12.8 image. Review these files before the first build:

- `.devcontainer/Dockerfile`: base image fallback and operating-system tools.
- `.devcontainer/devcontainer.json`: actual image build argument, GPUs, mounts,
  environment variables, and VS Code settings.
- `torch_constraints.txt`: Torch versions supplied by the base image.

### Choose PyTorch and CUDA

Set the same `BASE_IMAGE` in `Dockerfile` and in the `build.args` section of
`devcontainer.json`. Then update all three versions in
`torch_constraints.txt` to exactly match that image.

The current working set is:

```text
pytorch/pytorch:2.10.0-cuda12.8-cudnn9-devel
torch==2.10.0
torchvision==0.25.0
torchaudio==2.10.0
```

Use a `devel` image when compiling CUDA extensions. Add required Debian/Ubuntu
libraries to the existing `apt-get install` list in `Dockerfile`. Keep project
Python dependencies in `pyproject.toml`/`uv.lock`; do not install another Torch
stack in the Dockerfile.

### Select GPUs

For host GPU 0 only, keep:

```jsonc
"runArgs": [
  "--gpus=device=0",
  "--shm-size=16g",
  "--security-opt=no-new-privileges:true"
],
"containerEnv": {
  "CUDA_VISIBLE_DEVICES": "0"
}
```

To expose only host GPU 1, change `--gpus=device=0` to
`--gpus=device=1`. It is presented as logical CUDA device 0 inside the
container, so keep `CUDA_VISIBLE_DEVICES=0`.

To expose host GPUs 0 and 1:

```jsonc
"runArgs": [
  "--gpus",
  "device=0,1",
  "--shm-size=16g",
  "--security-opt=no-new-privileges:true"
],
"containerEnv": {
  "CUDA_VISIBLE_DEVICES": "0,1"
}
```

Remove the GPU argument and `CUDA_VISIBLE_DEVICES` for CPU-only development,
and select a CPU-compatible base image.

### Choose persistent storage

By default, the host stores ML data under:

```text
~/ml-storage/
├── datasets/
├── models/
├── outputs/
└── runs/
```

These appear inside the container as `/mnt/ml/datasets`, `/mnt/ml/models`,
`/mnt/ml/outputs`, and `/mnt/ml/runs`. To isolate projects, replace
`ml-storage` in `initializeCommand` and the four bind mounts with, for example,
`ml-storage/my-ml-project`.

Never place credentials in `Dockerfile`, `devcontainer.json`, Git, or a
committed `.env` file.

## 3. Open the project in VS Code

Install on the development machine:

- Docker;
- an NVIDIA driver and NVIDIA Container Toolkit for GPU development;
- VS Code with the **Dev Containers** extension;
- **Remote - SSH** as well when Docker runs on a remote GPU server.

For a local Docker host:

```bash
cd my-ml-project
code .
```

Then open the VS Code Command Palette and run:

```text
Dev Containers: Reopen in Container
```

For a remote GPU server:

1. Run **Remote-SSH: Connect to Host...**.
2. Open the cloned repository on that server.
3. Run **Dev Containers: Reopen in Container**.

The first build downloads the base image and creates the persistent volumes.
The post-create step runs `uv sync --frozen` and enables the repository Git
hooks. After changing `Dockerfile`, `devcontainer.json`, or
`torch_constraints.txt`, run **Dev Containers: Rebuild Container**.

Verify the environment inside the VS Code terminal:

```bash
test -f /.dockerenv
nvidia-smi

python - <<'PY'
import os
import torch

print("torch:", torch.__version__)
print("torch location:", torch.__file__)
print("CUDA available:", torch.cuda.is_available())
print("visible GPUs:", torch.cuda.device_count())
print("CUDA_VISIBLE_DEVICES:", os.environ.get("CUDA_VISIBLE_DEVICES"))
if torch.cuda.is_available():
    print("GPU 0:", torch.cuda.get_device_name(0))
PY

uv lock --check
uv run python -m unittest discover -s tests
```

Normal project commands are:

```bash
uv add PACKAGE
uv sync --frozen
uv run python -m my_ml_project
uv run python -m unittest discover -s tests
```

Use `codex login` inside the container if the project uses Codex. Codex,
Hugging Face, Torch, `uv`, `.venv`, and agent-worktree state are stored in
named volumes and survive container rebuilds.
