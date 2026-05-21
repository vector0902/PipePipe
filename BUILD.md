# PipePipe 构建指南

## 概述

本项目使用 Docker 构建 PipePipe Android 应用。构建过程将源代码编译成 APK 文件。

## 构建命令

### 完整构建（推荐）

```bash
docker compose -f docker-compose.build.yml up --build
```

此命令会：
1. 构建 Docker 镜像（包含 JDK 17、Android SDK 和源代码）
2. 在镜像内编译 APK
3. 将生成的 APK 文件复制到 `./outputs/` 目录

### 仅复制 APK（镜像已构建时）

如果 Docker 镜像已经构建完成，可以跳过构建步骤直接复制 APK：

```bash
docker compose -f docker-compose.build.yml up
```

## 输出文件

构建完成后，APK 文件将位于 `./outputs/` 目录：

| 文件名 | 大小 | 说明 |
|--------|------|------|
| PipePipe_5.0.0-arm64-v8a-debug.apk | ~49M | ARM64 设备（现代手机）|
| PipePipe_5.0.0-armeabi-v7a-debug.apk | ~41M | ARMv7 设备（旧手机）|
| PipePipe_5.0.0-universal-debug.apk | ~58M | 通用版本（所有架构）|
| PipePipe_5.0.0-x86_64-debug.apk | ~50M | x86_64 设备（模拟器）|
| PipePipe_5.0.0-x86-debug.apk | ~41M | x86 设备（旧模拟器）|

## 技术细节

### Dockerfile 说明

- **基础镜像**: `eclipse-temurin:17-jdk` (Java 17)
- **Android SDK**: 版本 33，构建工具 33.0.2
- **构建方式**: 源代码在构建时复制到镜像内编译
- **构建时间**: 约 8-10 分钟

### 关键文件

- `Dockerfile` - Docker 镜像定义
- `docker-compose.build.yml` - 构建编排配置
- `PipePipeClient/` - 主应用源代码
- `PipePipeExtractor/` - 提取器库源代码

## 故障排除

### 内存不足错误 (exit code 137)

如果构建过程中容器被终止，可能是内存不足。确保系统至少有 8GB 可用内存。

### 清理构建缓存

```bash
docker compose -f docker-compose.build.yml down
docker rmi pipepipe-builder:latest
```

## 注意事项

- 首次构建需要下载 Gradle 和依赖库，耗时较长
- 后续构建会利用 Docker 层缓存，速度更快
- 构建过程中需要网络连接下载依赖
