#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <remote_host> <project_name>"
    echo "Exemplo: $0 humberto-work test_003"
    exit 1
fi

REMOTE_HOST="$1"
PROJECT_NAME="$2"

echo ">> Conectando em ${REMOTE_HOST} para remover projeto ${PROJECT_NAME} em ~/projects/${PROJECT_NAME} ..."

ssh "$REMOTE_HOST" bash -s "$PROJECT_NAME" << 'REMOTE_SCRIPT'
set -euo pipefail

PROJECT_NAME="$1"
PROJECTS_DIR="$HOME/projects"
PROJECT_PATH="${PROJECTS_DIR}/${PROJECT_NAME}"

echo ">> [1/4] Removendo containers Docker que utilizam o path: ${PROJECT_PATH} ..."

if command -v docker >/dev/null 2>&1; then
    CONTAINERS=""

    # 1) Tenta achar containers com o label padrão dos DevContainers
    BY_LABEL=$(docker ps -aq --filter "label=devcontainer.local_folder=${PROJECT_PATH}" || true)
    if [ -n "${BY_LABEL}" ]; then
        echo "   Containers encontrados por label devcontainer.local_folder:"
        docker ps -a --format '{{.ID}} {{.Names}} {{.Labels}}' \
            | grep "devcontainer.local_folder=${PROJECT_PATH}" || true
        CONTAINERS="${CONTAINERS} ${BY_LABEL}"
    fi

    # 2) Plano B: varre todos os containers e checa mounts
    for cid in $(docker ps -aq); do
        MOUNTS=$(docker inspect -f '{{ range .Mounts }}{{ .Source }} {{ end }}' "$cid" 2>/dev/null || true)
        if echo "$MOUNTS" | grep -q "${PROJECT_PATH}"; then
            CONTAINERS="${CONTAINERS} ${cid}"
        fi
    done

    # Normaliza espaços
    CONTAINERS=$(echo "${CONTAINERS}" | xargs -r echo || true)

    if [ -n "${CONTAINERS}" ]; then
        echo "   Containers a remover:"
        docker ps -a --format '{{.ID}} {{.Names}} {{.Mounts}} {{.Labels}}' \
            | grep -E "$(echo "${CONTAINERS}" | sed 's/ /|/g')" || true

        # Captura imagens associadas
        IMAGES=$(docker inspect -f '{{.Image}}' ${CONTAINERS} 2>/dev/null | sort -u || true)

        echo "   Removendo containers (e volumes anônimos) ..."
        docker rm -fv ${CONTAINERS} || true

        if [ -n "${IMAGES}" ]; then
            echo ">> [2/4] Removendo imagens Docker associadas aos containers ..."
            docker rmi -f ${IMAGES} || true
        else
            echo ">> [2/4] Nenhuma imagem associada encontrada (ou já removida)."
        fi
    else
        echo "   Nenhum container encontrado usando esse projeto."
        echo ">> [2/4] Pulando remoção de imagens (nenhum container associado encontrado)."
    fi

    echo ">> [3/4] Removendo volumes Docker com nome contendo: ${PROJECT_NAME} (se existirem) ..."
    VOLUMES=$(docker volume ls --filter "name=${PROJECT_NAME}" -q || true)
    if [ -n "${VOLUMES}" ]; then
        echo "   Volumes encontrados: ${VOLUMES}"
        docker volume rm ${VOLUMES} || true
    else
        echo "   Nenhum volume encontrado com esse nome."
    fi
else
    echo "   Docker não encontrado nesse host. Pulando remoção de containers/imagens/volumes."
    echo ">> [2/4] e [3/4] ignorados (sem Docker)."
fi

echo ">> [4/4] Removendo pasta do projeto em ${PROJECT_PATH} ..."
if [ -d "${PROJECT_PATH}" ]; then
    rm -rf "${PROJECT_PATH}"
    echo "   Pasta removida."
else
    echo "   Pasta não existe. Nada a remover."
fi

echo ">> Remoção concluída."
REMOTE_SCRIPT
