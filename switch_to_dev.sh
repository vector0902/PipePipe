#!/bin/bash

set -e

BRANCH_NAME="dev"
MAIN_REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo " Switch to branch: ${BRANCH_NAME}"
echo " Main repo: ${MAIN_REPO_DIR}"
echo "=========================================="

cd "${MAIN_REPO_DIR}"

CURRENT_BRANCH=$(git branch --show-current)
echo "[Main Repo] Current branch: ${CURRENT_BRANCH}"

if [ "${CURRENT_BRANCH}" = "${BRANCH_NAME}" ]; then
    echo "[MainRepo] Already on '${BRANCH_NAME}' branch, skip."
else
    echo "[Main Repo] Creating and switching to '${BRANCH_NAME}' branch..."
    git checkout -b "${BRANCH_NAME}"
fi

if [ -f .gitmodules ]; then
    echo ""
    echo "=========================================="
    echo " Processing submodules..."
    echo "=========================================="

    git submodule sync --recursive
    git submodule update --init --recursive

    while IFS= read -r line; do
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

                SUB_CURRENT=$(git branch --show-current 2>/dev/null || echo "detached")
                echo "[${SUBMODULE_NAME}] Current branch: ${SUB_CURRENT}"

                if [ "${SUB_CURRENT}" = "${BRANCH_NAME}" ]; then
                    echo "[${SUBMODULE_NAME}] Already on '${BRANCH_NAME}', skip."
                else
                    echo "[${SUBMODULE_NAME}] Creating/switching to '${BRANCH_NAME}'..."
                    git checkout -b "${BRANCH_NAME}" 2>/dev/null || git checkout "${BRANCH_NAME}"
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

    echo ""
    echo "Updating .gitmodules branch references..."
    sed -i "s/^\([[:space:]]*branch[[:space:]]*=\).*/\1 ${BRANCH_NAME}/" .gitmodules

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
    echo "No .gitmodules found, no submodules to process."
fi

echo ""
echo "Done! All repositories are now on '${BRANCH_NAME}' branch."
