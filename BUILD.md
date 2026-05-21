# PipePipe 构建指南

## 概述

本项目使用 Docker 构建 PipePipe Android 应用。构建系统分为两个阶段：
1. **首次构建** - 使用 `docker-compose.build.yml` 创建包含所有依赖的镜像
2. **后续构建** - 使用 `docker-compose.yml` 复用缓存进行增量编译

## 构建命令

### 首次构建（或代码大幅更新后）

```bash
docker compose -f docker-compose.build.yml up --build
```

此命令会：
1. 构建 Docker 镜像（包含 JDK 17、Android SDK）
2. 将源代码复制到镜像内
3. 在镜像中编译 APK（下载 Gradle 和依赖库）
4. 将生成的 APK 文件复制到 `./outputs/` 目录

**耗时**：8-10 分钟  
**输出**：5 个 APK 文件

### 后续构建（复用缓存，增量编译）

```bash
docker compose up
```

此命令会：
1. 使用已有的 Docker 镜像
2. 挂载源代码和缓存目录
3. 复用已下载的 Gradle、依赖库和构建输出
4. 只编译修改的文件
5. 将 APK 复制到 `./outputs/` 目录

**耗时**：1-3 分钟  
**特点**：增量编译，速度快

## 输出文件

构建完成后，APK 文件位于 `./outputs/` 目录：

| 文件名 | 大小 | 说明 |
|--------|------|------|
| PipePipe_5.0.0-arm64-v8a-debug.apk | ~49M | ARM64 设备（现代手机）|
| PipePipe_5.0.0-armeabi-v7a-debug.apk | ~41M | ARMv7 设备（旧手机）|
| PipePipe_5.0.0-universal-debug.apk | ~58M | 通用版本（所有架构）|
| PipePipe_5.0.0-x86_64-debug.apk | ~50M | x86_64 设备（模拟器）|
| PipePipe_5.0.0-x86-debug.apk | ~41M | x86 设备（旧模拟器）|

## 技术架构

### 组件下载时机

```
Dockerfile / Dockerfile.build
├── FROM eclipse-temurin:17-jdk          ← 基础镜像（已包含 JDK 17）
├── RUN apt-get install ...              ← 安装工具
├── RUN wget android-sdk.zip             ← 下载 Android SDK（约 1GB）
├── RUN sdkmanager "platforms;android-33" ← 下载平台工具（约 500MB）
│                                           这些都在镜像构建时完成！
└── ...

docker-compose.build.yml（首次构建）
├── 构建镜像（包含 SDK）
├── COPY 代码到镜像
├── RUN ./gradlew assembleDebug
│   ├── 下载 Gradle 7.5（约 100MB）→ 缓存到 /root/.gradle
│   ├── 下载依赖库（约 500MB）→ 缓存到 /root/.gradle/caches
│   └── 编译 APK
└── APK 在镜像中

docker-compose.yml（后续构建，复用缓存）
├── 使用已有镜像（包含 SDK）
├── volumes:
│   ├── ./gradle-cache:/root/.gradle      ← 复用 Gradle 缓存
│   ├── ./android-sdk:/opt/android-sdk-host ← 复用 SDK
│   └── ./build:/app/PipePipeClient/app/build ← 复用构建输出
├── 挂载代码（不是 COPY）
├── RUN ./gradlew assembleDebug
│   ├── 使用已下载的 Gradle（不重新下载）
│   ├── 使用已下载的依赖库（不重新下载）
│   └── 增量编译（只编译修改的文件）
└── 复制 APK 到 outputs
```

### 缓存复用机制

| 组件 | 首次构建 | 后续构建 | 复用方式 |
|------|----------|----------|----------|
| **JDK 17** | 从基础镜像获取 | 从基础镜像获取 | Docker 镜像层 |
| **Android SDK** | 镜像构建时下载 | 已包含在镜像中 | Docker 镜像层 |
| **Gradle** | 运行时下载 | 从 gradle-cache 卷复用 | 卷挂载 |
| **依赖库** | 运行时下载 | 从 gradle-cache 卷复用 | 卷挂载 |
| **构建输出** | 新生成 | 从 build 卷增量编译 | 卷挂载 |

### 关键卷挂载说明

```yaml
volumes:
  # Gradle 缓存 - 包含 Gradle wrapper、下载的依赖库
  - ./gradle-cache:/root/.gradle
  
  # Android SDK - 首次运行时从镜像复制到宿主机，后续复用
  - ./android-sdk:/opt/android-sdk-host
  
  # 构建输出 - 包含 .class 文件、资源等，支持增量编译
  - ./build:/app/PipePipeClient/app/build
```

## 文件说明

| 文件 | 用途 |
|------|------|
| `Dockerfile` | 基础镜像定义（JDK + Android SDK），用于后续构建 |
| `Dockerfile.build` | 完整镜像定义（包含代码编译），用于首次构建 |
| `docker-compose.yml` | 后续构建配置（挂载代码和缓存） |
| `docker-compose.build.yml` | 首次构建配置（复制代码到镜像） |
| `PipePipeClient/` | 主应用源代码 |
| `PipePipeExtractor/` | 提取器库源代码 |

## 故障排除

### 内存不足错误 (exit code 137)

如果容器被终止，可能是内存不足。`docker-compose.yml` 已配置：
```yaml
mem_limit: 12g
memswap_limit: 12g
```

### 清理构建缓存

```bash
# 停止容器
docker compose down
docker compose -f docker-compose.build.yml down

# 删除镜像（下次会重新构建）
docker rmi pipepipe-builder:latest

# 删除缓存目录
rm -rf ./gradle-cache ./build ./android-sdk
```

### 强制重新构建

```bash
# 不使用缓存重新构建镜像
docker compose -f docker-compose.build.yml build --no-cache
docker compose -f docker-compose.build.yml up
```

## 注意事项

1. **首次构建必须成功**：`docker-compose.yml` 依赖 `docker-compose.build.yml` 生成的镜像
2. **网络连接**：首次构建需要下载 Gradle 和依赖库
3. **磁盘空间**：缓存目录可能占用 2-3GB 空间
4. **增量编译**：修改代码后使用 `docker-compose up` 可快速重新编译
