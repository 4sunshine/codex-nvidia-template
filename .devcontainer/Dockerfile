ARG BASE_IMAGE=pytorch/pytorch:2.7.1-cuda12.8-cudnn9-devel
ARG NODE_IMAGE=node:22.22.0-bookworm-slim

FROM ${NODE_IMAGE} AS node-runtime
FROM ${BASE_IMAGE}

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG CODEX_VERSION=0.145.0
ARG UV_VERSION=0.8.13

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bubblewrap \
        build-essential \
        ca-certificates \
        curl \
        git \
        jq \
        libseccomp2 \
        openssh-client \
        python3-venv \
        ripgrep \
        util-linux \
    && python3 -m venv /opt/uv \
    && /opt/uv/bin/python -m pip install --no-cache-dir "uv==${UV_VERSION}" \
    && ln -s /opt/uv/bin/uv /usr/local/bin/uv \
    && groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" \
        --create-home --shell /bin/bash "${USERNAME}" \
    && rm -rf /var/lib/apt/lists/*

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
