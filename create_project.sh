#!/usr/bin/env bash
set -euo pipefail

#######################################################################################
# Usage:
#   Simple mode (no GitHub integration):
#     ./create_project.sh <remote_host> <project_name>
#
#   GitHub mode (create private repo, commit + push):
#     ./create_project.sh <remote_host> <project_name> <github_user> <github_repo_name>
#
#   Example:
#     ./create_project.sh user@server project_name github_user projectX_name_on_hithub
#######################################################################################

if [ "$#" -ne 2 ] && [ "$#" -ne 4 ]; then
    echo "Usage:"
    echo "  $0 <remote_host> <project_name>"
    echo "  $0 <remote_host> <project_name> <github_user> <github_repo_name>"
    echo
    echo "Examples:"
    echo "  $0 user@host project_001"
    echo "  $0 user@host project_001 mygithubuser mynewrepo"
    exit 1
fi

REMOTE_HOST="$1"
PROJECT_NAME="$2"

ENABLE_GITHUB=false
GITHUB_USER=""
GITHUB_REPO_NAME=""

if [ "$#" -eq 4 ]; then
    ENABLE_GITHUB=true
    GITHUB_USER="$3"
    GITHUB_REPO_NAME="$4"
fi

echo ">> Connecting to ${REMOTE_HOST} and creating project ${PROJECT_NAME} in ~/projects/${PROJECT_NAME} ..."

ssh "$REMOTE_HOST" bash -s "$PROJECT_NAME" << 'REMOTE_SCRIPT'
set -euo pipefail

PROJECT_NAME="$1"
PROJECTS_DIR="$HOME/projects"

echo ">> Creating directories at ${PROJECTS_DIR}/${PROJECT_NAME} ..."
mkdir -p "${PROJECTS_DIR}/${PROJECT_NAME}/.devcontainer"
cd "${PROJECTS_DIR}/${PROJECT_NAME}"

echo ">> Creating Dockerfile ..."

cat > Dockerfile << 'DOCKEREOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

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

echo ">> Creating devcontainer.json ..."

MOUNT_SRC="$HOME"
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

echo ">> Project created at ${PROJECTS_DIR}/${PROJECT_NAME}"
REMOTE_SCRIPT

###############################################################################
# Optional GitHub integration (private repo + initial commit + push)
###############################################################################

if [ "$ENABLE_GITHUB" = true ]; then
    echo ">> GitHub integration enabled."
    echo ">> A private repository will be created at https://github.com/${GITHUB_USER}/${GITHUB_REPO_NAME}"

    echo
    read -s -p "Enter your GitHub Personal Access Token (will not be displayed): " GITHUB_TOKEN
    echo

    if [ -z "${GITHUB_TOKEN}" ]; then
        echo "Error: empty GitHub token. Aborting GitHub integration."
        exit 1
    fi

    echo ">> Creating private repository on GitHub..."

    CREATE_REPO_HTTP_CODE=$(
        curl -sS -w "%{http_code}" -o /tmp/github_create_repo_response.json \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            https://api.github.com/user/repos \
            -d "{\"name\":\"${GITHUB_REPO_NAME}\",\"private\":true}"
    )

    if [ "${CREATE_REPO_HTTP_CODE}" -ge 300 ]; then
        echo "Error creating GitHub repository. HTTP code: ${CREATE_REPO_HTTP_CODE}"
        echo "Details saved to /tmp/github_create_repo_response.json"
        echo "Check whether the repo already exists or if the token has 'repo' permissions."
        exit 1
    fi

    echo ">> GitHub repository ${GITHUB_USER}/${GITHUB_REPO_NAME} created successfully."

    echo ">> Initializing git repository on remote machine and pushing first commit..."

    ssh "$REMOTE_HOST" bash -lc "set -euo pipefail
        cd \"\$HOME/projects/${PROJECT_NAME}\"

        if [ ! -d .git ]; then
            git init
            git branch -M main
        fi

        git add .
        git commit -m 'Initial commit from remote-docker-lab' || echo '>> Nothing to commit.'

        git remote remove origin 2>/dev/null || true

        git remote add origin https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO_NAME}.git

        git push -u origin main
    "

    echo ">> Git repository initialized and first push completed."
    echo ">> NOTE: The remote URL contains the token. It is recommended to switch to SSH:"
    echo "   cd ~/projects/${PROJECT_NAME}"
    echo "   git remote set-url origin git@github.com:${GITHUB_USER}/${GITHUB_REPO_NAME}.git"
fi

echo ">> Done."
