# Android TV Bilibili - Full Plan

## Project Overview

将 tvOS 版 Bilibili 客户端移植到 Android TV 平台。使用 Kotlin + Jetpack Compose for TV + ExoPlayer + DanmakuFlameMaster。

## Tech Stack

| Component | Choice | Version |
|---|---|---|
| Language | Kotlin | 2.0+ |
| UI | Jetpack Compose for TV | `androidx.tv.compose` |
| Player | Media3 ExoPlayer | `androidx.media3` |
| Danmaku | DanmakuFlameMaster | `com.github.ctiao:DanmakuFlameMaster:0.9.25` |
| Network | OkHttp + Retrofit | 4.x / 2.x |
| Serialization | kotlinx.serialization | 1.7+ |
| Async | Coroutines + Flow | 1.8+ |
| Image | Coil (Compose) | 2.x |
| DI | Hilt | 2.51+ |
| Navigation | Navigation Compose | 2.7+ |
| Persistence | DataStore | 1.1+ |
| Logging | Timber | 5.0 |
| Protobuf | protobuf-kotlin | 3.x |
| WebSocket | OkHttp WebSocket | 4.x |
| Brotli | Brotli4j | 1.16+ |

## Directory Structure

```
Android/code/
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/bilibili/tv/
│       │   ├── App.kt                          # Application class
│       │   ├── MainActivity.kt                  # Single Activity
│       │   ├── navigation/
│       │   │   └── AppNavigation.kt             # NavHost + routes
│       │   ├── data/
│       │   │   ├── model/                       # Data classes (mirror iOS Codable)
│       │   │   │   ├── VideoDetail.kt
│       │   │   │   ├── DynamicFeed.kt
│       │   │   │   ├── LiveRoom.kt
│       │   │   │   ├── Bangumi.kt
│       │   │   │   ├── FavData.kt
│       │   │   │   ├── HistoryData.kt
│       │   │   │   ├── LoginToken.kt
│       │   │   │   ├── Account.kt
│       │   │   │   └── PlayerInfo.kt
│       │   │   ├── remote/
│       │   │   │   ├── BilibiliApi.kt           # Retrofit interface
│       │   │   │   ├── WbiSignInterceptor.kt    # WBI signing
│       │   │   │   ├── AppSignInterceptor.kt    # MD5 signing (for passport API)
│       │   │   │   └── CookieManager.kt
│       │   │   ├── repository/
│       │   │   │   ├── AuthRepository.kt
│       │   │   │   ├── FeedRepository.kt
│       │   │   │   ├── VideoRepository.kt
│       │   │   │   └── LiveRepository.kt
│       │   │   └── local/
│       │   │       ├── SettingsDataStore.kt     # DataStore preferences
│       │   │       └── AccountDataStore.kt
│       │   ├── domain/
│       │   │   └── model/
│       │   │       ├── DisplayData.kt           # Interface for UI display
│       │   │       └── PlayableData.kt          # Interface for playable items
│       │   ├── ui/
│       │   │   ├── theme/
│       │   │   │   └── Theme.kt                 # Material3 TV Theme
│       │   │   ├── component/
│       │   │   │   ├── VideoCard.kt             # Feed card composable
│       │   │   │   ├── OverlayInfo.kt           # Play count / danmaku overlay
│       │   │   │   └── AvatarImage.kt
│       │   │   ├── screen/
│       │   │   │   ├── login/
│       │   │   │   │   └── LoginScreen.kt
│       │   │   │   ├── home/
│       │   │   │   │   └── HomeScreen.kt        # Tab host
│       │   │   │   ├── feed/
│       │   │   │   │   └── FeedScreen.kt        # 推荐
│       │   │   │   ├── hot/
│       │   │   │   │   └── HotScreen.kt         # 热门
│       │   │   │   ├── follows/
│       │   │   │   │   └── FollowsScreen.kt     # 关注
│       │   │   │   ├── live/
│       │   │   │   │   └── LiveScreen.kt        # 直播
│       │   │   │   ├── ranking/
│       │   │   │   │   └── RankingScreen.kt     # 排行榜
│       │   │   │   ├── favorite/
│       │   │   │   │   └── FavoriteScreen.kt    # 收藏
│       │   │   │   ├── personal/
│       │   │   │   │   └── PersonalScreen.kt    # 我的
│       │   │   │   ├── settings/
│       │   │   │   │   └── SettingsScreen.kt    # 设置
│       │   │   │   ├── player/
│       │   │   │   │   ├── PlayerScreen.kt      # 播放器
│       │   │   │   │   └── PlayerViewModel.kt
│       │   │   │   ├── search/
│       │   │   │   │   └── SearchScreen.kt
│       │   │   │   ├── history/
│       │   │   │   │   └── HistoryScreen.kt
│       │   │   │   └── detail/
│       │   │   │       └── VideoDetailScreen.kt
│       │   │   └── video/
│       │   │       └── VideoGridScreen.kt       # Generic video grid (reusable)
│       │   ├── player/
│       │   │   ├── BiliPlayer.kt                # ExoPlayer wrapper
│       │   │   ├── DashMediaSourceFactory.kt    # DASH source creation
│       │   │   └── QualitySelector.kt
│       │   ├── danmaku/
│       │   │   ├── DanmakuBridge.kt             # DanmakuFlameMaster + Compose bridge
│       │   │   ├── DanmakuProvider.kt           # WebSocket provider for live
│       │   │   └── VideoDanmakuProvider.kt      # Protobuf provider for video
│       │   ├── proto/
│       │   │   ├── dm.proto                     # Protobuf definition
│       │   │   └── dmView.proto
│       │   └── util/
│       │       ├── BrotliDecompressor.kt
│       │       ├── BvidConvertor.kt
│       │       └── QrCodeGenerator.kt
│       └── res/
│           └── ...
├── build.gradle.kts                             # Root build file
├── settings.gradle.kts
└── gradle.properties
```

## Module Mapping (iOS -> Android)

### 1. Entry & Navigation

| iOS File | Android Equivalent |
|---|---|
| `AppDelegate.swift` | `App.kt` (Hilt Application) + `MainActivity.kt` |
| `BLTabBarViewController` | `HomeScreen.kt` with `TabRow` or custom sidebar |
| `TabBarPage.swift` | `sealed class TabPage` enum |
| `TabBarPageFactory` | Navigation routes in `AppNavigation.kt` |

### 2. Network Layer

| iOS File | Android Equivalent |
|---|---|
| `ApiRequest.swift` (416 lines) | `BilibiliApi.kt` (Retrofit interface) + `AppSignInterceptor.kt` |
| `WebRequest.swift` (1187 lines) | `BilibiliApi.kt` (continued) + repositories |
| `WebRequest+WbiSign.swift` | `WbiSignInterceptor.kt` (OkHttp Interceptor) |
| `CookieManager.swift` | `CookieManager.kt` (OkHttp CookieJar) |
| `AccountManager.swift` | `AccountDataStore.kt` + `AuthRepository.kt` |

### 3. Data Models

| iOS File | Android Equivalent |
|---|---|
| `VideoDetail` struct | `VideoDetail.kt` (@Serializable data class) |
| `DynamicFeedData` struct | `DynamicFeed.kt` |
| `LiveRoom` struct | `LiveRoom.kt` |
| `BangumiInfo` struct | `Bangumi.kt` |
| `FavData` struct | `FavData.kt` |
| `HistoryData` struct | `HistoryData.kt` |
| `LoginToken` struct | `LoginToken.kt` |
| `dm.pb.swift` | `dm.pb.kt` (protoc generated) |

### 4. Player

| iOS File | Android Equivalent |
|---|---|
| `CommonPlayerViewController` | `PlayerScreen.kt` + `BiliPlayer.kt` |
| `BilibiliVideoResourceLoaderDelegate` | **DELETE** - ExoPlayer handles DASH natively |
| `CommonPlayerPlugin` protocol | ExoPlayer `Player.Listener` + custom extensions |
| `URLPlayPlugin` | ExoPlayer `MediaItem` configuration |
| `SpeedChangerPlugin` | ExoPlayer `setPlaybackSpeed()` |
| `DanmuViewPlugin` | `DanmakuBridge.kt` |
| `SponsorSkipPlugin` | `SponsorBlockInterceptor.kt` |
| `MaskViewPlugin` | Android `MaskProvider.kt` (future) |
| `DebugPlugin` | ExoPlayer `DebugTextViewHelper` |
| `SidxParseUtil.swift` | **DELETE** - ExoPlayer handles SIDX |

### 5. Danmaku

| iOS File | Android Equivalent |
|---|---|
| `DanmakuKit/*` (8 files) | DanmakuFlameMaster library |
| `DanmuViewPlugin.swift` | `DanmakuBridge.kt` |
| `VideoDanmuProvider.swift` | `VideoDanmakuProvider.kt` |
| `LiveDanMuProvider.swift` | `DanmakuProvider.kt` |
| `BrotliDecompressor.swift` | `BrotliDecompressor.kt` (Brotli4j) |
| `dm.pb.swift` | protoc generated `dm.pb.kt` |
| `dmView.pb.swift` | protoc generated `dmView.pb.kt` |
| `VideoDanmuFilter.swift` | `DanmuFilter.kt` |

### 6. UI Screens

| iOS File | Android Equivalent |
|---|---|
| `LoginViewController.swift` | `LoginScreen.kt` |
| `FeedViewController.swift` | `FeedScreen.kt` |
| `HotViewController.swift` | `HotScreen.kt` |
| `FollowsViewController.swift` | `FollowsScreen.kt` |
| `LiveViewController.swift` | `LiveScreen.kt` |
| `RankingViewController.swift` | `RankingScreen.kt` |
| `FavoriteViewController.swift` | `FavoriteScreen.kt` |
| `PersonalViewController.swift` | `PersonalScreen.kt` |
| `SettingsViewController.swift` | `SettingsScreen.kt` |
| `VideoDetailViewController.swift` | `VideoDetailScreen.kt` |
| `SearchResultViewController.swift` | `SearchScreen.kt` |
| `HistoryViewController.swift` | `HistoryScreen.kt` |
| `AccountSwitcherViewController.swift` | `AccountSwitcherSheet.kt` |

### 7. Reusable UI Components

| iOS File | Android Equivalent |
|---|---|
| `FeedCollectionViewController` | `VideoGridScreen.kt` (Composable) |
| `FeedCollectionViewCell` | `VideoCard.kt` (Composable) |
| `BLOverlayView` | `OverlayInfo.kt` (Composable) |
| `BLButton` / `BLCustomButton` | Standard Compose `Button` with D-pad focus |
| `BLMotionCollectionViewCell` | **DELETE** - no motion effects |
| `BLSettingLineCollectionViewCell` | `SettingsItem.kt` (Composable) |
| `MarqueeLabel` | Compose `basicMarquee()` modifier |

### 8. Removed (Not Needed)

| iOS File | Reason |
|---|---|
| `BilibiliVideoResourceLoaderDelegate.swift` | ExoPlayer handles DASH natively |
| `SidxParseUtil.swift` | ExoPlayer handles SIDX natively |
| `DLNA/*` | User request: no casting |
| All `BLMotionCollectionViewCell` focus/motion code | User request: no motion effects |
| `PocketSVG` dependency | Not needed |
| `MarqueeLabel` dependency | Compose has `basicMarquee()` |

## Implementation Phases

### Phase 1: Project Setup (3 days)
- Gradle configuration with all dependencies
- Hilt setup
- Basic Compose TV theme
- Data model classes (all `@Serializable`)
- DataStore for settings and accounts

### Phase 2: Network Layer (1.5 weeks)
- OkHttp client with interceptors
- WBI signing interceptor (移植 `WebRequest+WbiSign.swift`)
- MD5 signing for passport API (移植 `ApiRequest.sign()`)
- Cookie management (OkHttp CookieJar)
- Retrofit interface for all API endpoints
- Repository classes (Auth, Feed, Video, Live)

### Phase 3: Auth & Login (3 days)
- QR code generation (Android `QRCode` library)
- Login screen with polling
- Account management (multi-account support)
- Token refresh logic

### Phase 4: Video Player (1.5 weeks)
- ExoPlayer integration
- DASH playback (native, no custom ResourceLoader)
- Quality selection (1080p/4K/HDR)
- Playback speed control
- PlayerScreen with controls overlay
- D-pad key handling for play/pause/seek

### Phase 5: Danmaku (1 week)
- DanmakuFlameMaster integration via `AndroidView`
- Video danmaku (Protobuf parser)
- Live danmaku (WebSocket + Brotli)
- Danmaku settings (area, size, opacity, speed)

### Phase 6: Main UI Framework (2 weeks)
- Home screen with tab navigation
- Video grid layout (`TvLazyVerticalGrid`, fixed 4 columns)
- Video card component
- Detail screen
- All feed screens (Feed, Hot, Live, Ranking, Follows, Favorite)

### Phase 7: Secondary Screens (1.5 weeks)
- Settings screen
- Search screen
- History screen
- Personal/profile screen
- Account switcher

### Phase 8: Polish & Testing (1 week)
- D-pad navigation refinements
- Error handling
- Loading states
- Edge cases (expired token, network errors)

## Key Technical Decisions

1. **No custom DASH resource loading** - ExoPlayer handles DASH natively, eliminates ~500 lines of complex code
2. **DanmakuFlameMaster via AndroidView** - Battle-tested Bilibili engine, wrapped in Compose
3. **Fixed 4-column grid** - Simpler than iOS adaptive layout
4. **No motion effects** - Standard Android TV D-pad focus
5. **Hilt DI** - Clean separation, testable repositories
6. **DataStore over SharedPreferences** - Modern, coroutine-friendly

## Total Estimated Time: ~10 weeks (1 person)
