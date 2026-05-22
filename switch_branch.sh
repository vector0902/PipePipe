#!/bin/bash

set -e

BRANCH_NAME="${1:-dev}"
CREATE_NEW="${2:-false}"
MAIN_REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
    echo "Usage: bash $0 <branch_name> [--create|-c]"
    echo ""
    echo "Arguments:"
    echo "  branch_name    Target branch name (default: dev)"
    echo "  --create, -c   Force create new branch if not exists"
    echo ""
    echo "Examples:"
    echo "  bash $0 dev          # Switch to dev (create if not exists)"
    echo "  bash $0 main         # Switch to main (must exist)"
    echo "  bash $0 feature-x -c # Force create feature-x branch"
    exit 1
}

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
fi

if [ "$2" = "-c" ] || [ "$2" = "--create" ]; then
    CREATE_NEW="true"
fi

echo "=========================================="
echo " Switch to branch: ${BRANCH_NAME}"
echo " Mode: $([ "${CREATE_NEW}" = "true" ] && echo 'FORCE CREATE' || echo 'SMART SWITCH')"
echo " Main repo: ${MAIN_REPO_DIR}"
echo "=========================================="

cd "${MAIN_REPO_DIR}"

switch_branch() {
    local repo_name="$1"
    local target_branch="$2"
    local force_create="$3"

    local current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
    echo "[${repo_name}] Current branch: ${current_branch}"

    if [ "${current_branch}" = "${target_branch}" ]; then
        echo "[${repo_name}] Already on '${target_branch}', skip."
        return 0
    fi

    local branch_exists=false
    if git show-ref --verify --quiet "refs/heads/${target_branch}" 2>/dev/null; then
        branch_exists=true
    fi

    if [ "${branch_exists}" = true ]; then
        echo "[${repo_name}] Branch '${target_branch}' exists, switching..."
        git checkout "${target_branch}"
    else
        local remote_branch_exists=false
        if git ls-remote --heads origin "${target_branch}" 2>/dev/null | grep -q "${target_branch}"; then
            remote_branch_exists=true
        fi

        if [ "${remote_branch_exists}" = true ]; then
            echo "[${repo_name}] Remote branch 'origin/${target_branch}' found, creating local branch with tracking..."
            git checkout -b "${target_branch}" --track "origin/${target_branch}"
        elif [ "${force_create}" = "true" ] || [ "${target_branch}" = "dev" ]; then
            echo "[${repo_name}] Creating new branch '${target_branch}'..."
            git checkout -b "${target_branch}"
        else
            echo "[ERROR] ${repo_name}: Branch '${target_branch}' does not exist!"
            echo "        Use --create flag to force create, or check the branch name."
            return 1
        fi
    fi

    return 0
}

echo ""
echo "--- Main Repository ---"
if ! switch_branch "MainRepo" "${BRANCH_NAME}" "${CREATE_NEW}"; then
    exit 1
fi

if [ -f .gitmodules ]; then
    echo ""
    echo "=========================================="
    echo " Processing submodules..."
    echo "=========================================="

    git submodule sync --recursive 2>/dev/null || true
    git submodule update --init --recursive 2>/dev/null || true

    SUBMODULE_NAME=""
    SUBMODULE_PATH=""
    SUBMODULE_BRANCH=""

    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/[[:space:]]*$//')

        if [[ "$line" =~ ^\[submodule\ \"(.+)\"\]$ ]]; then
            SUBMODULE_NAME="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            SUBMODULE_PATH="${BASH_REMATCH[1]}"
        fi

        if [[ "$line" =~ ^[[:space:]]*branch[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            SUBMODULE_BRANCH="${BASH_REMATCH[1]}"
        fi

        if [[ -n "$SUBMODULE_NAME" && -n "$SUBMODULE_PATH" && "$line" =~ ^[[:space:]]*url ]]; then
            echo ""
            echo "------------------------------------------"
            echo " Submodule: ${SUBMODULE_NAME}"
            echo " Path: ${SUBMODULE_PATH}"
            echo " Target branch: ${BRANCH_NAME}"
            echo "------------------------------------------"

            if [ -d "${SUBMODULE_PATH}" ]; then
                cd "${SUBMODULE_PATH}"

                if ! switch_branch "${SUBMODULE_NAME}" "${BRANCH_NAME}" "${CREATE_NEW}"; then
                    echo "[WARNING] Failed to switch submodule: ${SUBMODULE_NAME}"
                fi

                cd "${MAIN_REPO_DIR}"
            else
                echo "[WARNING] Submodule path not found: ${SUBMODULE_PATH}"
            fi

            SUBMODULE_NAME=""
            SUBMODULE_PATH=""
            SUBMODULE_BRANCH=""
        fi
    done < .gitmodules

    if [ "${CREATE_NEW}" = "true" ] || [ "${BRANCH_NAME}" != "main" ]; then
        echo ""
        echo "Updating .gitmodules branch references to '${BRANCH_NAME}'..."
        sed -i "s/^\([[:space:]]*branch[[:space:]]*=\).*/\1 ${BRANCH_NAME}/" .gitmodules
    fi

    echo ""
    echo "=========================================="
    echo " Summary"
    echo "=========================================="
    echo "Main repo branch:"
    git branch --show-current
    echo ""
    echo "Submodule branches:"
    git submodule status --recursive
else
    echo ""
    echo "No .gitmodules found, no submodules to process."
fi

echo ""
echo "=========================================="
echo " Branch tracking status:"
echo "=========================================="
git branch -vv | cat
echo ""
echo "=========================================="
echo " Done! All repositories processed."
echo "=========================================="
