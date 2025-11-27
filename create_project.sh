#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <remote_host> <project_name>"
    echo "Exemplo: $0 humberto-work cplex_env310"
    exit 1
fi

REMOTE_HOST="$1"
PROJECT_NAME="$2"

echo ">> Conectando em ${REMOTE_HOST} e criando projeto ${PROJECT_NAME} em ~/projects/${PROJECT_NAME} ..."

ssh "$REMOTE_HOST" bash -s "$PROJECT_NAME" << 'REMOTE_SCRIPT'
set -euo pipefail

PROJECT_NAME="$1"
PROJECTS_DIR="$HOME/projects"

echo ">> Criando diretórios em ${PROJECTS_DIR}/${PROJECT_NAME} ..."
mkdir -p "${PROJECTS_DIR}/${PROJECT_NAME}/.devcontainer"
cd "${PROJECTS_DIR}/${PROJECT_NAME}"

echo ">> Criando Dockerfile ..."

cat > Dockerfile << 'DOCKEREOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Habilita todos os repositórios padrão
RUN sed -i 's/^# deb/deb/' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
        python3.10 python3.10-venv python3-pip \
        build-essential wget curl git nano sudo ca-certificates \
        language-pack-pt \
        r-base gfortran liblapack-dev liblapack3 libopenblas-dev \
        make perl gcc cmake libcurl4-openssl-dev libssl-dev vim unrar htop \
        openjdk-18-jdk \
        libfontconfig1-dev r-cran-devtools libfreetype-dev libpng-dev \
        libtiff5-dev libjpeg-dev libharfbuzz-dev libfribidi-dev libxml2-dev \
        maven net-tools qemu-system-x86 libvirt-daemon bzip2 libclang-dev \
        zenity cron rustc cargo \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

WORKDIR /workspace
DOCKEREOF

echo ">> Criando devcontainer.json ..."

MOUNT_SRC="$HOME"   # /home/<usuario> na máquina remota
mkdir -p .devcontainer

cat > .devcontainer/devcontainer.json << JSONEOF
{
    "name": "${PROJECT_NAME}-dev",
    "build": {
        "dockerfile": "../Dockerfile"
    },
    "workspaceFolder": "/workspace",
    "remoteUser": "root",
    "mounts": [
        "source=${MOUNT_SRC},target=/shared_folder,type=bind"
    ],
    "customizations": {
        "vscode": {
            "extensions": [
                "ms-python.python",
                "ms-python.vscode-pylance"
            ]
        }
    }
}
JSONEOF

echo ">> Projeto criado em ${PROJECTS_DIR}/${PROJECT_NAME}"
REMOTE_SCRIPT
