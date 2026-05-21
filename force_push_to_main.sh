#!/bin/bash

set -e

MAIN_REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_NAME="${1:-origin}"
CONFIRM_TOKEN="${2:-}"

echo "=========================================="
echo " DANGER: FORCE PUSH TO MAIN BRANCH"
echo " Remote: ${REMOTE_NAME}"
echo "=========================================="
echo ""
echo "WARNING: This operation will:"
echo "  1. Reset 'main' branch to match 'dev' branch"
echo "  2. FORCE PUSH to remote (overwrites remote history!)"
echo "  3. Apply to: Main Repo + ALL submodules"
echo ""
echo "This CANNOT be undone easily!"
echo ""

if [ "${CONFIRM_TOKEN}" != "I_UNDERSTAND_THE_RISKS" ]; then
    echo "To proceed, you must explicitly confirm by running:"
    echo ""
    echo "  bash $0 ${REMOTE_NAME} I_UNDERSTAND_THE_RISKS"
    echo ""
    echo "This safety measure prevents accidental data loss."
    exit 1
fi

read -p "Are you ABSOLUTELY sure? (type 'yes' to continue): " user_confirm
if [ "${user_confirm}" != "yes" ]; then
    echo "Operation cancelled."
    exit 0
fi

cd "${MAIN_REPO_DIR}"

force_push_to_main() {
    local repo_name="$1"
    local remote="$2"

    echo ""
    echo "--- Processing: ${repo_name} ---"

    local current_branch=$(git branch --show-current)
    echo "[${repo_name}] Current branch: ${current_branch}"

    if [ "${current_branch}" != "dev" ]; then
        echo "[${repo_name}] Switching to 'dev' branch..."
        git checkout dev
    fi

    local dev_commit=$(git rev-parse dev)
    echo "[${repo_name}] Dev commit: ${dev_commit}"

    echo "[${repo_name}] Checking if 'main' branch exists locally..."
    if git show-ref --verify --quiet refs/heads/main; then
        local main_commit=$(git rev-parse main)
        echo "[${repo_name}] Main commit (before): ${main_commit}"
        echo "[${repo_name}] Resetting 'main' to 'dev'..."
        git reset --hard dev
    else
        echo "[${repo_name}] Creating 'main' from 'dev'..."
        git branch -m dev main
        git checkout -b dev
        git checkout main
    fi

    echo "[${repo_name}] Force pushing to ${remote}/main..."
    git push ${remote} main --force

    echo "[${repo_name}] Switching back to 'dev'..."
    git checkout dev

    echo "[${repo_name}] Done!"
}

echo ""
echo "=========================================="
echo " Step 1: Main Repository"
echo "=========================================="
force_push_to_main "MainRepo" "${REMOTE_NAME}"

if [ -f .gitmodules ]; then
    echo ""
    echo "=========================================="
    echo " Step 2: Submodules"
    echo "=========================================="

    SUBMODULE_NAME=""
    SUBMODULE_PATH=""

    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/[[:space:]]*$//')

        if [[ "$line" =~ ^\[submodule\ \"(.+)\"\]$ ]]; then
            SUBMODULE_NAME="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*path[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            SUBMODULE_PATH="${BASH_REMATCH[1]}"
        fi

        if [[ -n "$SUBMODULE_NAME" && -n "$SUBMODULE_PATH" && "$line" =~ ^[[:space:]]*url ]]; then
            if [ -d "${SUBMODULE_PATH}" ]; then
                cd "${SUBMODULE_PATH}"
                force_push_to_main "${SUBMODULE_NAME}" "${REMOTE_NAME}"
                cd "${MAIN_REPO_DIR}"
            else
                echo "[WARNING] Submodule path not found: ${SUBMODULE_PATH}"
            fi

            SUBMODULE_NAME=""
            SUBMODULE_PATH=""
        fi
    done < .gitmodules
fi

echo ""
echo "=========================================="
echo " Summary"
echo "=========================================="
echo "Main repo:"
git branch -vv | grep -E "(main|dev)"
echo ""
echo "Submodules:"
git submodule status --recursive
echo ""
echo "=========================================="
echo " SUCCESS: All repositories force-pushed!"
echo "=========================================="
