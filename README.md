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

# Give the Dev Container a recognizable VS Code display name and ensure every
# named Docker volume is unique for this fork.
sed -i \
  -e "s/Codex NVIDIA development/${PROJECT_SLUG} development/g" \
  -e "s/codex-nvidia-template/${PROJECT_SLUG}/g" \
  .devcontainer/devcontainer.json
```

Changing the top-level `name` in `devcontainer.json` is optional; it is a
display label and does not control the repository, image, or volume names. It
is recommended when several Dev Containers run on the same machine. Renaming
the `source=codex-nvidia-template-*` volume prefixes is more important because
unrelated forks must not share project-specific `.venv` or worktree volumes.

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

### Export and reuse trained models

`models` and `outputs` are host bind mounts, so files written there already
belong to the host user and survive container rebuilds. Do not use `docker cp`.
Train into `$OUTPUTS_DIR`, then promote the selected checkpoint inside the
container:

```bash
MODEL_NAME=my-model-v1.pth

install -m 0644 \
  "$OUTPUTS_DIR/my-run/checkpoint_best.pth" \
  "$MODELS_DIR/$MODEL_NAME"

sha256sum "$MODELS_DIR/$MODEL_NAME"
```

On the Docker host, the same file is immediately available at:

```bash
# Use "$HOME/ml-storage" when the optional per-project directory was not set.
HOST_ML_ROOT="$HOME/ml-storage/my-ml-project"

ls -lh "$HOST_ML_ROOT/models"
sha256sum "$HOST_ML_ROOT/models/my-model-v1.pth"
```

When Docker runs on a remote GPU server, copy the model to a workstation from
a local terminal:

```bash
mkdir -p ./models
scp GPU_HOST:~/ml-storage/my-ml-project/models/my-model-v1.pth ./models/
```

Use the model outside the development container only with a compatible Python,
framework, and CUDA environment:

```bash
MODEL_PATH="$HOST_ML_ROOT/models/my-model-v1.pth"
uv run python your_inference_script.py --checkpoint "$MODEL_PATH"
```

The safer reproducible option is another container with the model directory
mounted read-only:

```bash
docker run --rm --gpus device=0 \
  --mount "type=bind,src=$HOST_ML_ROOT/models,dst=/models,readonly" \
  your-inference-image \
  python /app/infer.py --checkpoint /models/my-model-v1.pth
```

Do not run training as root, commit model files to Git, or load untrusted
pickled checkpoints. Record the model hash and the code/environment version
used to produce it.

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

### Optional: allow agents to push `agent/*` branches

Use a dedicated GitHub deploy key for each repository instead of giving an
agent a personal SSH key.

The bundled helper is the easiest self-contained setup. Run it as the non-root
Dev Container user from the repository root:

```bash
scripts/setup-agent-ssh YOUR_ORG/my-ml-project
```

The helper validates `origin`, generates an unencrypted repository-specific
Ed25519 key under `~/.ssh`, displays only its public key, waits while you add it
to GitHub, requires manual verification of GitHub's port-443 host fingerprint,
and configures only this repository for HTTPS fetches and SSH-over-443 pushes.
It refuses an unrelated remote and never overwrites an existing private key.

The generated key is local to this container and is deliberately not stored in
the repository or a shared project volume. Replacing the container may remove
it; in that case, revoke the old GitHub deploy key and run the helper again.

For a key that survives container replacement without storing private material
inside the container, generate it as your normal user on the trusted Docker
host or workstation and forward it with `ssh-agent`:

```bash
AGENT_KEY="$HOME/.ssh/my-ml-project-agent"

umask 077
ssh-keygen -t ed25519 -a 100 \
  -C "my-ml-project agent deploy key" \
  -f "$AGENT_KEY"

# Enter the passphrase once; the agent receives access through ssh-agent.
ssh-add "$AGENT_KEY"
cat "${AGENT_KEY}.pub"
```

In GitHub, open **Repository Settings → Deploy keys → Add deploy key**, paste
only the `.pub` value, and select **Allow write access**. A deploy key grants
access to one repository and cannot be reused for another repository. See
[GitHub's deploy-key guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys).

VS Code forwards the running `ssh-agent` socket into the Dev Container. Reopen
the container after loading the key, then verify only its fingerprint inside:

```bash
test -S "$SSH_AUTH_SOCK"
ssh-add -l
```

Use HTTPS for fetches and repository-scoped SSH over port 443 for pushes. This
works on networks that block GitHub SSH port 22:

```bash
git remote set-url origin \
  https://github.com/YOUR_ORG/my-ml-project.git

git remote set-url --push origin \
  ssh://git@ssh.github.com:443/YOUR_ORG/my-ml-project.git

git fetch origin
```

The helper performs the same repository-local remote setup automatically.

Configure commit identity locally, create an `agent/*` branch, and open a pull
request instead of pushing directly to `main`:

```bash
git config --local user.name "YOUR_AGENT_NAME"
git config --local user.email "YOUR_AGENT_EMAIL"

TASK_SLUG=add-evaluation
git switch -c "agent/${TASK_SLUG}" origin/main

git add -- PATHS_TO_COMMIT
git diff --cached
git commit -m "Add evaluation workflow"
git push -u origin "agent/${TASK_SLUG}"
```

The SSH key authenticates Git pushes; it does not enforce the branch prefix or
set commit identity. Protect `main` with a GitHub ruleset that requires pull
requests and blocks force pushes/deletions. The repository's pre-push hook adds
a local guard, but server-side protection is authoritative. Never copy the
private key into the repository, `.env`, Docker image, volume, prompt, or log.
Revoke the deploy key in GitHub immediately if the host or forwarded agent is
compromised. GitHub documents the port-443 endpoint in its
[SSH-over-HTTPS guide](https://docs.github.com/en/authentication/troubleshooting-ssh/using-ssh-over-the-https-port).

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
