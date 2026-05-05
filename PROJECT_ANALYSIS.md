# PipePipe 项目分析文档

## 1. 项目概述 / Project Overview

PipePipe 是 NewPipe 的一个硬分支（hard fork），于2022年初从 NewPipe 独立开发。这是一个免费开源的安卓视频/音频播放器，支持多平台内容源。

**PipePipe is a hard fork of NewPipe**, a free and open-source Android video/audio player supporting multiple content platforms.

### 主要支持平台 / Supported Platforms
- YouTube
- BiliBili (哔哩哔哩)
- PeerTube
- NicoNico
- 以及更多...

---

## 2. 项目结构 / Project Structure

```
PipePipe/
├── PipePipeClient/          # Android 应用主项目
│   ├── app/                 # 应用模块
│   │   └── src/main/
│   │       ├── java/        # Java/Kotlin 源代码
│   │       └── res/         # 资源文件
│   ├── build.gradle         # Gradle 构建配置
│   └── gradle/              # Gradle wrapper
│
├── PipePipeExtractor/       # 数据提取库
│   ├── extractor/           # 核心提取逻辑
│   ├── timeago-parser/      # 时间格式化
│   └── build.gradle
│
├── PipePipe.wiki/           # 项目 wiki 文档
├── assets/                  # 静态资源
└── fastlane/metadata/       # 应用市场元数据
```

---

## 3. 技术栈 / Tech Stack

| 类别 | 技术 |
|------|------|
| **平台** | Android |
| **语言** | Java + Kotlin |
| **构建工具** | Gradle 7.3.0 |
| **Kotlin 版本** | 1.7.20 |
| **compileSdk** | 33 |
| **minSdk** | 21 |
| **targetSdk** | 33 |
| **架构** | Clean Architecture |

### 主要依赖 / Key Dependencies
- **AndroidX** - Android 扩展库
- **Room** - 数据库
- **ExoPlayer** - 音视频播放
- **Picasso** - 图片加载
- **Jsoup** - HTML 解析

---

## 4. 构建要求 / Build Requirements

### 环境要求
- **Java JDK 17** ✅ 已安装
- **Android SDK** ❌ 未安装
- **Gradle** - 通过 wrapper 提供

### 构建命令
```bash
cd PipePipeClient
./gradlew assembleDebug    # 调试构建
./gradlew assembleRelease  # 发布构建
```

---

## 5. 功能特性 / Features

### YouTube 增强
- SponsorBlock 集成（跳过赞助段落）
- YouTube 不喜欢数显示（ReturnYouTubeDislike）
- 显示原始标题（非本地化）
- 登录访问受限/高级内容

### 媒体功能
- 弹幕式直播聊天显示
- AV1 和 VP9 编码支持
- 音乐播放器模式（后台播放）

### 播放控制
- 滑动手势搜索
- 长按加速播放
- 睡眠定时器

### 播放列表
- 批量下载整个播放列表
- 本地播放列表内搜索和排序

---

## 6. 构建状态 / Build Status

| 组件 | 状态 |
|------|------|
| Git 子模块 | ✅ 已初始化 |
| Java 环境 | ✅ JDK 17 |
| Gradle Wrapper | ✅ 可用 |
| Android SDK | ❌ 未安装 |
| 构建准备 | ⏳ 待安装 Android SDK |

---

## 7. 构建尝试 / Build Attempt

**解决方案**: 需要安装 Android SDK（cmdline-tools 或完整 SDK）。

### 安装建议 / Installation Suggestion
```bash
# 安装 Android SDK cmdline-tools
mkdir -p ~/android-sdk/cmdline-tools
cd ~/android-sdk/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest

# 设置环境变量
export ANDROID_HOME=~/android-sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# 安装所需 SDK 组件
sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.2"
```
