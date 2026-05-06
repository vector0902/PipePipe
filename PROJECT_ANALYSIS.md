# PipePipe 项目详细分析文档

## 1. 项目概述

PipePipe 是 NewPipe 的硬分支（hard fork），2022年初从 NewPipe 独立开发。这是一个免费开源的 Android 视频/音频播放器，支持多平台内容源。

**核心特点：**
- 无需 Google Play Services 即可运行
- 不需要任何账户
- 保护用户隐私
- 支持后台播放和画中画模式

---

## 2. 项目架构

```
PipePipe/
├── PipePipeClient/          # Android 应用主项目
│   ├── app/src/main/java/org/schabi/newpipe/
│   │   ├── player/           # 播放器核心（基于 ExoPlayer）
│   │   ├── fragments/        # UI 碎片（Activity, Fragment）
│   │   ├── local/            # 本地数据管理（订阅、播放列表、历史）
│   │   ├── database/         # Room 数据库
│   │   ├── download/         # 下载管理
│   │   ├── error/            # 错误处理
│   │   └── info_list/        # 信息列表展示
│   └── ...
│
├── PipePipeExtractor/       # 数据提取库（核心逻辑）
│   ├── extractor/src/main/java/org/schabi/newpipe/extractor/
│   │   ├── stream/           # 视频流提取
│   │   ├── services/         # 各平台服务实现
│   │   │   ├── youtube/      # YouTube 实现
│   │   │   ├── bilibili/     # B站 实现
│   │   │   └── soundcloud/   # SoundCloud 实现
│   │   ├── sponsorblock/     # SponsorBlock API
│   │   └── ...
│   └── timeago-parser/       # 时间格式化
```

---

## 3. 技术栈详解

| 组件 | 技术选型 | 说明 |
|------|----------|------|
| **播放器内核** | ExoPlayer (Media3) | Google 官方推荐的 Android 媒体播放库 |
| **数据库** | Room | SQLite ORM，支持 MVVM |
| **网络请求** | OkHttp + Retrofit | HTTP 客户端 |
| **HTML解析** | Jsoup | DOM 解析 |
| **响应式编程** | RxJava 3 | 异步数据流处理 |
| **依赖注入** | Icepick | 状态保存 |
| **图片加载** | Picasso | 图片缓存和加载 |

---

## 4. 核心功能模块详解

### 4.1 视频提取模块 (Extractor)

**位置：** `PipePipeExtractor/extractor/`

**核心类结构：**
```
StreamingService (抽象基类)
├── YoutubeService          # YouTube 实现
├── BilibiliService         # B站 实现
├── SoundcloudService       # SoundCloud 实现
└── PeerTubeService         # PeerTube 实现

StreamExtractor (视频提取器)
├── 提取视频信息（标题、描述、缩略图）
├── 提取可用流（视频流、音频流、字幕）
├── 提取建议和评论
```

**YouTube 提取流程：**
1. `YoutubeStreamLinkHandlerFactory` 解析 URL
2. `YoutubeStreamExtractor.fetchPage()` 获取页面
3. 解析 `playerResponse` JSON 获取视频详情
4. 从 `streamingData` 提取可用的流 URL
5. 处理签名解密（`deobfuscate()`）

**关键代码流程：**
```java
// YoutubeStreamExtractor.java
public String getName() throws ParsingException {
    // 从 playerResponse 中提取视频标题
    return playerResponse.getObject("videoDetails").getString("title");
}

public List<VideoStream> getVideoStreams() throws ParsingException {
    // 解析 streamingData 获取视频流
    JsonObject streamingData = playerResponse.getObject("streamingData");
    // 处理不同格式：adaptiveFormats, formattedStreams
}
```

---

### 4.2 播放器模块 (Player)

**位置：** `PipePipeClient/app/src/main/java/org/schabi/newpipe/player/`

**核心类：**
```
Player.java                 # 主播放器 Activity
PlayerService.java          # 后台播放服务
PlayQueue.java              # 播放队列管理
MediaSourceManager.java     # 媒体源管理
VideoPlaybackResolver.java  # 视频流解析
AudioPlaybackResolver.java # 音频流解析
```

**播放流程：**
1. 用户点击视频 → 创建 `StreamInfo` 提取任务
2. `MediaSourceManager` 创建 `MediaSource`
3. `VideoPlaybackResolver` 解析视频流 URL
4. `AudioPlaybackResolver` 解析音频流 URL
5. ExoPlayer 接收 MediaSource 开始播放

**支持的格式：**
- HLS (m3u8)
- DASH (mpd)
- Progressive (mp4, webm)
- AV1, VP9, H.264 编码

**SponsorBlock 集成：**
```java
// 播放器获取赞助段落
SponsorBlockSegment[] segments =
    SponsorBlockExtractorHelper.getSegments(extractor, settings);

// 播放时跳过赞助段落
player.addListener(new PlayerEventListener() {
    @Override
    public void onPositionDiscontinuity(...) {
        // 检查当前时间是否在赞助段落中
        for (SponsorBlockSegment segment : segments) {
            if (currentPosition >= segment.startTime
                && currentPosition <= segment.endTime) {
                player.seekTo(segment.endTime);
            }
        }
    }
});
```

---

### 4.3 下载模块

**位置：** `PipePipeClient/app/src/main/java/org/schabi/newpipe/download/`

**核心类：**
```
DownloadDialog.java          # 下载对话框
DownloadManagerService.java # 下载服务（后台运行）
DownloadManager.java        # 下载任务管理
```

**下载流程：**
1. 用户选择视频质量 → `DownloadDialog`
2. `DownloadManagerService` 创建下载任务
3. 使用 `okhttp` 下载文件
4. 支持断点续传（`MissionRecoveryInfo`）
5. 下载完成后执行后处理（`Postprocessing`）

**支持的下载类型：**
- 视频（MP4, WebM）
- 音频（MP3, M4A, FLAC）
- 字幕（SRT, TTML）
- 批量下载播放列表

---

### 4.4 数据库模块

**位置：** `PipePipeClient/app/src/main/java/org/schabi/newpipe/database/`

**使用 Room ORM，主要表结构：**

| 表名 | 说明 | 关键字段 |
|------|------|----------|
| `subscription` | 订阅频道 | service_id, url, name, thumbnail_url |
| `search_history` | 搜索历史 | query, creation_date |
| `stream` | 视频信息缓存 | service_id, url, title, thumbnail_url |
| `stream_history` | 观看历史 | stream_id, access_date, duration |
| `playlist` | 本地播放列表 | name, thumbnail_url |
| `playlist_stream` | 播放列表项 | playlist_id, stream_id, index |
| `feed_group` | 订阅分组 | name, icon_id, sort_order |

**关键 DAO：**
```java
@Dao
public interface SubscriptionDAO {
    @Query("SELECT * FROM subscription ORDER BY name")
    Flowable<List<SubscriptionEntity>> getAll();

    @Insert
    Completable insert(SubscriptionEntity entity);

    @Delete
    Completable delete(SubscriptionEntity entity);
}
```

---

### 4.5 订阅与 Feed 模块

**位置：** `PipePipeClient/app/src/main/java/org/schabi/newpipe/local/feed/`

**核心类：**
```
FeedFragment.java           # Feed 界面
FeedLoadService.java        # 后台更新服务
FeedLoadManager.java        # 加载管理
NotificationHelper.java     # 通知管理
```

**Feed 更新流程：**
1. `FeedLoadManager` 检查订阅更新
2. `FeedLoadService` 后台执行更新
3. 解析每个订阅频道的新视频
4. 生成通知（可选）
5. 更新 UI

**通知功能：**
- 定期检查新视频（可配置间隔）
- 显示新视频数量
- 点击跳转到视频

---

### 4.6 搜索模块

**位置：** `PipePipeClient/app/src/main/java/org/schabi/newpipe/fragments/list/search/`

**核心类：**
```
SearchFragment.java          # 搜索界面
SearchExtractor.java         # 搜索结果提取
SuggestionExtractor.java     # 搜索建议
SearchFilterLogic.java       # 搜索过滤逻辑
```

**搜索流程：**
1. 用户输入查询词
2. 本地历史匹配（立即显示）
3. 网络请求获取搜索建议（`SuggestionExtractor`）
4. 执行搜索（`SearchExtractor`）
5. 渲染结果列表

**YouTube 搜索过滤：**
```java
// 支持的过滤类型
- 视频类型：视频、频道、播放列表
- 时长：4分钟以下、4-20分钟、20分钟以上
- 日期：今天、本周、本月
- 排序：相关性、评分、上传日期、观看次数
```

---

### 4.7 BiliBili 支持

**位置：** `PipePipeExtractor/extractor/src/main/java/org/schabi/newpipe/extractor/services/bilibili/`

**PipePipe 独有的功能，B站特定支持：**

1. **弹幕获取**
   ```java
   // BilibiliService.java
   BulletCommentsExtractor getBulletCommentsExtractor(linkHandler);
   ```

2. **弹幕播放**
   ```java
   // MovieBulletCommentsPlayer.java
   // 在视频上叠加显示弹幕
   ```

3. **B站 API 集成**
   - 使用 `appkey` 和 `appsec` 签名请求
   - 支持登录状态访问
   - 获取高码率视频流

4. **番剧支持**
   - 识别番剧/电影分类
   - 获取剧集列表

---

### 4.8 SponsorBlock 功能

**位置：** `PipePipeExtractor/extractor/src/main/java/org/schabi/newpipe/extractor/sponsorblock/`

**SponsorBlock API：**
```java
// SponsorBlockSegment.java
public class SponsorBlockSegment {
    public SponsorBlockCategory category;  // 赞助类型
    public long startTime;                 // 开始时间(ms)
    public long endTime;                   // 结束时间(ms)
    public SponsorBlockAction action;      // skip/poi
}
```

**赞助类别：**
| 类别 | 说明 |
|------|------|
| `SPONSOR` | 赞助商广告 |
| `INTRO` | 片头 |
| `OUTRO` | 片尾 |
| `INTERACTION` | 互动提醒（如"喜欢请点赞"） |
| `HIGHLIGHT` | 视频精华片段 |
| `SELF_PROMO` | 自推广 |
| `NON_MUSIC` | 非音乐部分（音乐视频） |
| `PREVIEW` | 预览 |
| `FILLER` | 无意义填充 |

---

### 4.9 画中画 (PiP) 支持

**实现方式：**
```java
// Player.java
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    pipController = new PictureInPictureController(this);
    pipController.enterPictureInPicture();
}
```

**触发条件：**
- 按 Home 键时
- 系统支持 PiP

---

### 4.10 后台播放与媒体会话

**媒体会话集成：**
```java
// MediaSessionManager.java
MediaSessionCompat mediaSession = new MediaSessionCompat(context, "PipePipe");
mediaSession.setCallback(new MediaSessionCallback());

// 支持的 Intent：
// - ACTION_PLAY
// - ACTION_PAUSE
// - ACTION_SKIP_TO_NEXT
// - ACTION_SKIP_TO_PREVIOUS
```

**通知控制：**
- 显示播放/暂停按钮
- 显示进度条
- 显示专辑封面
- 支持耳机线控

---

## 5. 关键数据流

### 5.1 视频播放数据流

```
用户点击视频
    ↓
NavigationHelper.openVideoPlayer()
    ↓
StreamInfoActivity.fetchStreamInfo()
    ↓
ExtractorHelper.getStreamInfo()
    ↓
YoutubeStreamExtractor.fetchPage()
    ↓
解析 playerResponse + streamingData
    ↓
创建 PlayQueue
    ↓
MediaSourceManager.resolveMediaSource()
    ↓
VideoPlaybackResolver.resolve()
    ↓
ExoPlayer.setMediaSource()
    ↓
开始播放
```

### 5.2 订阅更新数据流

```
FeedLoadService.onStartJob()
    ↓
FeedLoadManager.startLoading()
    ↓
遍历所有订阅
    ↓
FeedExtractor.fetchPage() 获取新视频
    ↓
对比数据库中的最后更新时间
    ↓
有新视频 → 更新数据库 → 发送通知
    ↓
更新 FeedLastUpdatedEntity
```

---

## 6. 权限需求

```xml
<!-- 网络访问 -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- 存储访问（下载） -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<!-- 后台播放 -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- 画中画 -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

<!-- 网络状态 -->
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

---

## 7. 配置与设置

**设置存储位置：** `PreferenceManager.getDefaultSharedPreferences()`

**主要设置项：**
| 设置项 | 说明 |
|--------|------|
| `content_country` | 内容国家（影响推荐和趋势） |
| `content_language` | 内容语言 |
| `search_history_size` | 搜索历史保存数量 |
| `download_path` | 默认下载路径 |
| `player_default_quality` | 默认播放质量 |
| `thumbnail_queue_size` | 缩略图队列大小 |
| `enableSponsorBlock` | 是否启用 SponsorBlock |
| `enableReturnYouTubeDislike` | 是否显示 YouTube 不喜欢数 |
| `download_max_retry` | 下载最大重试次数 |

---

## 8. 错误处理

**错误类型：**
```java
// ExtractionException - 提取失败
// ParsingException - 解析失败
// ReCaptchaException - 需要验证码
// ContentNotAvailableException - 内容不可用
// AgeRestrictedException - 年龄限制
// GeorestrictedException - 地区限制
```

**错误报告：**
```java
// ErrorUtil.java
public static void.showSnackbar(UserAction action, Throwable e) {
    // 显示错误信息
    // 可选：发送 ACRA 报告
}
```

---

## 9. 构建配置

**Gradle 配置关键点：**
```gradle
// app/build.gradle
android {
    compileSdk 33
    defaultConfig {
        applicationId "InfinityLoop1309.NewPipeEnhanced.Beta"
        minSdk 21
        targetSdk 33
        versionCode 1098
        versionName "5.0.0"
    }

    buildTypes {
        debug {
            // debug 签名
        }
        release {
            // 需要配置签名
            minifyEnabled true
            proguardFiles getDefaultProguardFile(...)
        }
    }
}
```

---

## 10. 总结

PipePipe 是一个功能完善的第三方 YouTube/BiliBili 客户端，核心优势：

1. **隐私保护** - 无需 Google 服务
2. **功能丰富** - SponsorBlock、后台播放、下载
3. **模块化设计** - Extractor 独立，便于扩展新平台
4. **开源透明** - 代码可审计

**开发重点领域：**
- 视频流提取（反爬虫对抗）
- ExoPlayer 定制（字幕、弹幕、播放控制）
- 后台服务稳定性
- 省电优化