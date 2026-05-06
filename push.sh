#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "=== 1. 检查并推送 PipePipeClient 子模块 ==="
cd PipePipeClient
if [ -n "$(git status -s)" ]; then
    echo "子模块有改动，先提交..."
    git add -A
    git commit -m "update Maven mirrors and build fixes"
fi
git push https://github.com/vector0902/PipePipeClient HEAD:dev

echo ""
echo "=== 2. 检查并推送 PipePipeExtractor 子模块 ==="
cd ../PipePipeExtractor
if [ -n "$(git status -s)" ]; then
    echo "子模块有改动，先提交..."
    git add -A
    git commit -m "update Maven mirrors"
fi
git push https://github.com/vector0902/PipePipeExtractor HEAD:main

echo ""
echo "=== 3. 更新主项目子模块引用 ==="
cd ..
git add PipePipeClient PipePipeExtractor
git commit -m "update submodule refs" || echo "Nothing to commit in main project"
git push origin main

echo ""
echo "=== 全部完成 ==="
