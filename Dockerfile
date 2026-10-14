ARG BASE_IMAGE=pytorch/pytorch:2.13.0-cuda12.6-cudnn9-devel
ARG NODE_IMAGE=node:22.22.0-bookworm-slim

FROM ${NODE_IMAGE} AS node-runtime
FROM ${BASE_IMAGE} AS codex-base

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG CODEX_VERSION=latest
ARG UV_VERSION=0.12.19

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bubblewrap \
        build-essential \
        ca-certificates \
        curl \
        ffmpeg \
        git \
        git-lfs \
        htop \
        jq \
        libgl1 \
        libglib2.0-0 \
        libseccomp2 \
        numactl \
        openssh-client \
        python3-venv \
        ripgrep \
        screen \
        tmux \
        unzip \
        util-linux \
        vim \
        wget \
    && git lfs install --system \
    && update-ca-certificates \
    && python3 -m venv /opt/uv \
    && /opt/uv/bin/python -m pip install --no-cache-dir "uv==${UV_VERSION}" \
    && ln -sfn /opt/uv/bin/uv /usr/local/bin/uv \
    && existing_group="$(getent group "${USER_GID}" | cut -d: -f1)" \
    && if [ -n "${existing_group}" ] && [ "${existing_group}" != "${USERNAME}" ]; then groupmod --new-name "${USERNAME}" "${existing_group}"; fi \
    && if ! getent group "${USERNAME}" >/dev/null; then groupadd --gid "${USER_GID}" "${USERNAME}"; fi \
    && existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)" \
    && if [ -n "${existing_user}" ] && [ "${existing_user}" != "${USERNAME}" ]; then usermod --login "${USERNAME}" --gid "${USERNAME}" --home "/home/${USERNAME}" --move-home "${existing_user}"; fi \
    && if ! getent passwd "${USERNAME}" >/dev/null; then useradd --uid "${USER_UID}" --gid "${USERNAME}" --create-home --shell /bin/bash "${USERNAME}"; fi \
    && rm -rf /var/lib/apt/lists/*

# Install locked analysis dependencies into the image's ordinary Python so
# direct python3 commands work without an activation step or runtime downloads.
# --inexact preserves unrelated packages already provided by the base image.
COPY pyproject.toml uv.lock /opt/amrvac-analysis/
RUN UV_PROJECT_ENVIRONMENT="$(python3 -c 'import sys; print(sys.prefix)')" \
        uv sync --project /opt/amrvac-analysis --locked --inexact \
        --no-dev --no-install-project --no-python-downloads \
        --python "$(command -v python3)" \
    && python3 -c 'import astropy, numpy, torch; assert astropy.__version__ == "8.0.1"; assert torch.from_numpy(numpy.zeros(1)).numpy().shape == (1,)'

# Fail the build if the CUDA-enabled PyTorch stack supplied by the base image
# drifts after analysis dependencies are installed.
COPY torch_constraints.txt /tmp/torch_constraints.txt
RUN python3 -c 'from importlib.metadata import version; from pathlib import Path; from packaging.specifiers import SpecifierSet; constraints = dict(line.strip().split("==", 1) for line in Path("/tmp/torch_constraints.txt").read_text().splitlines() if line.strip() and not line.lstrip().startswith("#")); mismatches = [f"{package}: expected =={expected}, found {version(package)}" for package, expected in constraints.items() if version(package) not in SpecifierSet(f"=={expected}")]; assert not mismatches, "; ".join(mismatches)'

COPY --from=node-runtime /usr/local/ /usr/local/

RUN npm install --global --omit=dev "@openai/codex@${CODEX_VERSION}" \
    && npm cache clean --force \
    && codex --version \
    && node --version \
    && uv --version

COPY .devcontainer/entrypoint.sh /usr/local/bin/template-entrypoint

RUN chmod 0755 /usr/local/bin/template-entrypoint \
    && chmod 0711 /home/vscode

ENTRYPOINT ["/usr/local/bin/template-entrypoint"]
CMD ["sleep", "infinity"]
