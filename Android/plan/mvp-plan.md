# Android TV Bilibili - MVP Plan

## MVP Scope

实现以下 5 个核心页面，构成完整的最小可用产品：

1. **登录** - QR 码扫码登录
2. **设置** - 基础设置项
3. **推荐 (Feed)** - 首页推荐视频流
4. **热门 (Hot)** - 热门视频列表
5. **关注 (Follows)** - 关注的 UP 主动态

## Tech Stack (MVP subset)

```
Kotlin, Jetpack Compose TV, Media3 ExoPlayer, OkHttp, Retrofit,
kotlinx.serialization, Coroutines+Flow, Coil, Hilt, DataStore, Timber
```

弹幕：MVP 暂不集成播放器弹幕（播放器先做基础播放），后续迭代加上 DanmakuFlameMaster。

## Important: UserAgent 模拟

必须使用 macOS Safari 的 UserAgent，这是 B站 API 的要求：
```
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15
```
Referer: `https://www.bilibili.com`

此 UserAgent 在 `Constants.kt` 中定义，所有 OkHttp client 通过 Interceptor 自动添加。

## Project Structure (MVP)

```
Android/code/
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/bilibili/tv/
│       │   ├── App.kt
│       │   ├── MainActivity.kt
│       │   ├── navigation/
│       │   │   └── AppNavigation.kt
│       │   ├── data/
│       │   │   ├── model/
│       │   │   │   ├── LoginToken.kt
│       │   │   │   ├── Account.kt
│       │   │   │   ├── VideoDetail.kt
│       │   │   │   ├── FeedData.kt
│       │   │   │   └── DynamicFeed.kt
│       │   │   ├── remote/
│       │   │   │   ├── BilibiliApi.kt
│       │   │   │   ├── AppSignInterceptor.kt
│       │   │   │   ├── WbiSignInterceptor.kt
│       │   │   │   └── CookieJarImpl.kt
│       │   │   ├── repository/
│       │   │   │   ├── AuthRepository.kt
│       │   │   │   ├── FeedRepository.kt
│       │   │   │   └── AccountRepository.kt
│       │   │   └── local/
│       │   │       ├── SettingsDataStore.kt
│       │   │       └── AccountDataStore.kt
│       │   ├── ui/
│       │   │   ├── theme/
│       │   │   │   └── Theme.kt
│       │   │   ├── component/
│       │   │   │   ├── VideoCard.kt
│       │   │   │   └── OverlayInfo.kt
│       │   │   └── screen/
│       │   │       ├── login/
│       │   │       │   ├── LoginScreen.kt
│       │   │       │   └── LoginViewModel.kt
│       │   │       ├── home/
│       │   │       │   └── HomeScreen.kt
│       │   │       ├── feed/
│       │   │       │   ├── FeedScreen.kt
│       │   │       │   └── FeedViewModel.kt
│       │   │       ├── hot/
│       │   │       │   ├── HotScreen.kt
│       │   │       │   └── HotViewModel.kt
│       │   │       ├── follows/
│       │   │       │   ├── FollowsScreen.kt
│       │   │       │   └── FollowsViewModel.kt
│       │   │       ├── settings/
│       │   │       │   └── SettingsScreen.kt
│       │   │       └── player/
│       │   │           └── PlayerScreen.kt
│       │   ├── player/
│       │   │   └── BiliPlayer.kt
│       │   └── util/
│       │       ├── BvidConvertor.kt
│       │       └── QrCodeGenerator.kt
│       └── res/
│           └── ...
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

## File-by-File Implementation Plan

### 1. Build Configuration

#### `settings.gradle.kts`
```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolution {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }  // DanmakuFlameMaster
    }
}
rootProject.name = "BilibiliTV"
include(":app")
```

#### Root `build.gradle.kts`
```kotlin
plugins {
    id("com.android.application") version "8.5.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.0" apply false
    id("org.jetbrains.kotlin.plugin.serialization") version "2.0.0" apply false
    id("com.google.dagger.hilt.android") version "2.51" apply false
    id("com.google.devtools.ksp") version "2.0.0-1.0.21" apply false
}
```

#### `app/build.gradle.kts`
Key dependencies:
```kotlin
// Compose TV
implementation("androidx.tv.compose:tv-compose:1.0.0-alpha12")
implementation("androidx.tv:tv-foundation:1.0.0-alpha12")

// Media3 ExoPlayer
implementation("androidx.media3:media3-exoplayer:1.4.1")
implementation("androidx.media3:media3-exoplayer-dash:1.4.1")
implementation("androidx.media3:media3-ui:1.4.1")

// Network
implementation("com.squareup.okhttp3:okhttp:4.12.0")
implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
implementation("com.squareup.retrofit2:retrofit:2.11.0")
implementation("com.squareup.retrofit2:converter-kotlinx-serialization:2.11.0")

// Serialization
implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.1")

// Coroutines
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

// Hilt
implementation("com.google.dagger:hilt-android:2.51")
ksp("com.google.dagger:hilt-android-compiler:2.51")
implementation("androidx.hilt:hilt-navigation-compose:1.2.0")

// Coil
implementation("io.coil-kt:coil-compose:2.6.0")

// DataStore
implementation("androidx.datastore:datastore-preferences:1.1.1")

// Timber
implementation("com.jakewharton.timber:timber:5.0.1")

// QR Code (for login)
implementation("com.github.alexzhirkevich:custom-qr-generator:2.0.0-beta01")
```

### 2. Application & Activity

#### `App.kt`
- `@HiltAndroidApp` Application class
- Initialize Timber logging
- Initialize AccountManager on startup

#### `MainActivity.kt`
- `@AndroidEntryPoint` single Activity
- Set Compose content with `AppNavigation()`
- Handle D-pad key events at top level
- Immersive mode (hide system bars)

### 3. Navigation (`AppNavigation.kt`)

```
NavHost:
  /login        -> LoginScreen
  /home         -> HomeScreen (tabs: Feed | Hot | Follows)
  /settings     -> SettingsScreen
  /player/{aid}/{cid} -> PlayerScreen
```

Logic:
- On startup, check `AccountDataStore.isLoggedIn()`
- If not logged in -> navigate to `/login`
- If logged in -> navigate to `/home`
- After successful login -> navigate to `/home`

### 4. Data Models

#### `LoginToken.kt`
```kotlin
@Serializable
data class LoginToken(
    val mid: Int,
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("expires_in") val expiresIn: Int,
    val expireDate: Long = 0  // epoch millis
)
```

#### `Account.kt`
```kotlin
@Serializable
data class Account(
    val token: LoginToken,
    val profile: Profile,
    val cookies: List<StoredCookie>,
    val lastActiveAt: Long
) {
    @Serializable
    data class Profile(
        val mid: Int,
        val username: String,
        val avatar: String
    )

    @Serializable
    data class StoredCookie(
        val name: String,
        val value: String,
        val domain: String,
        val path: String
    )
}
```

#### `VideoDetail.kt`
Map from iOS `VideoDetail.Info`:
```kotlin
@Serializable
data class VideoDetail(
    val View: Info,
    val Related: List<Info> = emptyList()
) {
    @Serializable
    data class Info(
        val aid: Int,
        val cid: Int = 0,
        val title: String,
        val pic: String? = null,
        val desc: String? = null,
        val owner: VideoOwner = VideoOwner(),
        val duration: Int = 0,
        val stat: Stat = Stat(),
        val pages: List<VideoPage>? = null,
        val bvid: String? = null
    )

    @Serializable
    data class VideoOwner(
        val mid: Int = 0,
        val name: String = "",
        val face: String? = null
    )

    @Serializable
    data class Stat(
        val view: Int = 0,
        val danmaku: Int = 0,
        val like: Int = 0,
        val coin: Int = 0,
        val favorite: Int = 0
    )

    @Serializable
    data class VideoPage(
        val cid: Int,
        val page: Int,
        val part: String
    )
}
```

#### `FeedData.kt`
Map from iOS `ApiRequest.FeedResp`:
```kotlin
@Serializable
data class FeedResp(
    val item: List<FeedItem> = emptyList()
) {
    @Serializable
    data class FeedItem(
        val param: String = "",      // aid as string
        val title: String = "",
        val cover: String? = null,
        val name: String = "",       // owner name
        val face: String? = null,    // avatar
        val stat: Stat = Stat(),
        val idx: Long = 0
    ) {
        @Serializable
        data class Stat(
            val view: Int = 0,
            val danmaku: Int = 0
        )

        val aid: Int get() = param.toIntOrNull() ?: 0
    }
}
```

#### `DynamicFeed.kt`
Map from iOS `DynamicFeedData`:
```kotlin
@Serializable
data class DynamicFeedInfo(
    val items: List<DynamicFeedData> = emptyList(),
    val offset: String = "",
    val has_more: Boolean = false
) {
    val videoFeeds: List<DynamicFeedData>
        get() = items.filter {
            it.modules.module_dynamic.major?.archive != null ||
            it.modules.module_dynamic.major?.pgc != null
        }
}

@Serializable
data class DynamicFeedData(
    val type: String = "",
    val id_str: String = "",
    val modules: Modules = Modules()
) {
    val aid: Int
        get() = modules.module_dynamic.major?.archive?.aid?.toIntOrNull() ?: 0
    val title: String
        get() = modules.module_dynamic.major?.archive?.title
            ?: modules.module_dynamic.major?.pgc?.title ?: ""
    val ownerName: String
        get() = modules.module_author.name
    val pic: String?
        get() = modules.module_dynamic.major?.archive?.cover
            ?: modules.module_dynamic.major?.pgc?.cover?.toString()
    val avatar: String?
        get() = modules.module_author.face

    @Serializable
    data class Modules(
        val module_author: ModuleAuthor = ModuleAuthor(),
        val module_dynamic: ModuleDynamic = ModuleDynamic()
    ) {
        @Serializable
        data class ModuleAuthor(
            val face: String = "",
            val mid: Int = 0,
            val name: String = "",
            val pub_time: String = ""
        )

        @Serializable
        data class ModuleDynamic(
            val major: Major? = null
        ) {
            @Serializable
            data class Major(
                val archive: Archive? = null,
                val pgc: Pgc? = null
            ) {
                @Serializable
                data class Archive(
                    val aid: String? = null,
                    val cover: String? = null,
                    val title: String? = null,
                    val duration_text: String? = null,
                    val stat: Stat? = null
                ) {
                    @Serializable
                    data class Stat(
                        val danmaku: String? = null,
                        val play: String? = null
                    )
                }

                @Serializable
                data class Pgc(
                    val epid: Int? = null,
                    val title: String? = null,
                    val cover: String? = null
                )
            }
        }
    }
}
```

### 5. Network Layer

#### `AppSignInterceptor.kt`
移植自 `ApiRequest.sign()`:
- 将参数按 key 排序
- 拼接 `appkey` + `appsec`
- MD5 签名
- 添加 `sign` 参数

Constants:
```kotlin
const val APP_KEY = "5ae412b53418aac5"
const val APP_SEC = "5b9cf6c9786efd204dcf0c1ce2d08436"
```

#### `WbiSignInterceptor.kt`
移植自 `WebRequest+WbiSign.swift`:
- 获取 wbi keys (img_key + sub_key)
- MixinKeyEncTab 混淆表
- 参数签名

#### `BilibiliApi.kt`
Retrofit interface, MVP 需要的 endpoints:

```kotlin
interface BilibiliApi {
    // Auth
    @POST("x/passport-tv-login/qrcode/auth_code")
    suspend fun getLoginQrCode(): ApiResponse<LoginQrResp>

    @POST("x/passport-tv-login/qrcode/poll")
    suspend fun pollLoginQr(
        @Field("auth_code") authCode: String
    ): ApiResponse<LoginPollResp>

    @POST("api/v2/oauth2/refresh_token")
    suspend fun refreshToken(
        @Field("refresh_token") refreshToken: String
    ): ApiResponse<RefreshTokenResp>

    // Feed (推荐)
    @GET("x/v2/feed/index")
    suspend fun getFeed(): ApiResponse<FeedResp>

    @GET("x/v2/feed/index")
    suspend fun getFeed(@Query("idx") idx: Long): ApiResponse<FeedResp>

    // Hot (热门)
    @GET("x/web-interface/popular")
    suspend fun getHot(
        @Query("pn") page: Int,
        @Query("ps") pageSize: Int = 40
    ): ApiResponse<HotResp>

    // Follows (关注动态)
    @GET("x/polymer/web-dynamic/v1/feed/all")
    suspend fun getFollowsFeed(
        @Query("type") type: String = "all",
        @Query("timezone_offset") tz: String = "-480",
        @Query("page") page: Int,
        @Query("offset") offset: Long? = null
    ): ApiResponse<DynamicFeedInfo>

    // Video detail
    @GET("x/web-interface/view")
    suspend fun getVideoDetail(@Query("aid") aid: Int): ApiResponse<VideoDetail.Info>

    // Play URL
    @GET("x/player/wbi/playurl")
    suspend fun getPlayUrl(
        @Query("avid") avid: Int,
        @Query("cid") cid: Int,
        @Query("qn") qn: Int,
        @Query("fnval") fnval: Int,
        @Query("fourk") fourk: Int = 1
    ): ApiResponse<PlayUrlInfo>

    // Login info
    @GET("x/web-interface/nav")
    suspend fun getNavInfo(): ApiResponse<NavInfo>
}
```

#### `CookieJarImpl.kt`
OkHttp `CookieJar` implementation:
- 从 `AccountDataStore` 加载 cookies
- 保存响应中的 cookies
- 提供 CSRF token

#### API Base URLs:
```
Passport: https://passport.bilibili.com/
Main API: https://api.bilibili.com/
App API:  https://app.bilibili.com/
```

两个 Retrofit instance（一个带 app sign，一个带 cookie + wbi sign）。

### 6. Repositories

#### `AuthRepository.kt`
```kotlin
class AuthRepository @Inject constructor(
    private val api: BilibiliApi,
    private val accountDataStore: AccountDataStore
) {
    suspend fun getLoginQrCode(): Pair<String, String>  // (authCode, qrUrl)
    suspend fun pollLogin(authCode: String): LoginState
    suspend fun refreshToken(): Boolean
    suspend fun logout()
    fun isLoggedIn(): Boolean
}
```

#### `FeedRepository.kt`
```kotlin
class FeedRepository @Inject constructor(
    private val api: BilibiliApi
) {
    suspend fun getFeed(idx: Long? = null): FeedResp
    suspend fun getHot(page: Int): HotResp
    suspend fun getFollowsFeed(offset: Long? = null, page: Int): DynamicFeedInfo
    suspend fun getVideoDetail(aid: Int): VideoDetail.Info
    suspend fun getPlayUrl(aid: Int, cid: Int, qn: Int, fnval: Int): PlayUrlInfo
}
```

### 7. Screens

#### LoginScreen.kt
- 左侧：QR 码图片（大尺寸，TV 可读）
- 右侧：说明文字 + "重新生成" 按钮
- 4 秒轮询检查登录状态
- 成功后导航到 HomeScreen
- 适配 D-pad：重新生成按钮可聚焦

#### HomeScreen.kt
- 侧边 Tab 栏：推荐 | 热门 | 关注 | 设置
- 右侧内容区域显示对应 Screen
- 使用 Compose `TabRow` 或自定义 sidebar
- D-pad 左右切换 Tab 和内容

#### FeedScreen.kt
- `TvLazyVerticalGrid` 固定 4 列
- 每个 item 是 `VideoCard` composable
- 下拉加载更多（基于 `idx` 分页）
- 点击 item 导航到 PlayerScreen

#### HotScreen.kt
- 同 FeedScreen 布局
- 基于 `pn` 分页
- 显示播放量、弹幕数 overlay

#### FollowsScreen.kt
- 同 FeedScreen 布局
- 基于 `offset` 分页
- 过滤非视频动态
- 显示 UP 主头像和名称

#### SettingsScreen.kt
- 简单列表设置项
- MVP 设置项：
  - 画质选择 (1080p / 4K)
  - 弹幕开关 (预留)
  - 账号信息显示
  - 登出按钮

#### PlayerScreen.kt
- ExoPlayer 全屏播放
- 基础控制：播放/暂停、进度条
- D-pad 操作：左/右 = 快退/快进，上/下 = 画质/设置
- 暂停时显示标题和进度

### 8. Components

#### `VideoCard.kt`
```kotlin
@Composable
fun VideoCard(
    title: String,
    coverUrl: String?,
    ownerName: String,
    avatarUrl: String? = null,
    playCount: Int = 0,
    danmakuCount: Int = 0,
    duration: String? = null,
    onClick: () -> Unit
)
```
- 16:9 封面图（Coil 加载）
- 底部渐变 overlay 显示播放量/弹幕数
- 底部标题 + UP 主名
- D-pad focus 时放大 + 边框高亮

#### `OverlayInfo.kt`
- 左侧：播放图标 + 数字，弹幕图标 + 数字
- 右侧：时长文本
- 半透明渐变背景

### 9. Player

#### `BiliPlayer.kt`
```kotlin
@Composable
fun BiliPlayer(
    playUrlInfo: PlayUrlInfo,
    title: String,
    onBack: () -> Unit
)
```
- 创建 ExoPlayer instance
- 配置 DASH `MediaSource`
- 选择最高画质 stream
- 全屏播放
- D-pad key event handling

## Implementation Order

| Step | Task | Files | Est. Time |
|---|---|---|---|
| 1 | Gradle + project skeleton | build files, App.kt, MainActivity.kt | 1 day |
| 2 | Data models | 6 model files | 0.5 day |
| 3 | Network layer - sign interceptors | AppSignInterceptor, WbiSignInterceptor | 1 day |
| 4 | Network layer - API + cookie | BilibiliApi, CookieJarImpl | 1 day |
| 5 | DataStore + AccountRepository | local/ files, AuthRepository | 1 day |
| 6 | Theme + VideoCard component | Theme.kt, VideoCard.kt, OverlayInfo.kt | 0.5 day |
| 7 | Login screen | LoginScreen, LoginViewModel | 1 day |
| 8 | Navigation + HomeScreen | AppNavigation, HomeScreen | 0.5 day |
| 9 | Feed screen + ViewModel | FeedScreen, FeedViewModel, FeedRepository | 1 day |
| 10 | Hot screen + ViewModel | HotScreen, HotViewModel | 0.5 day |
| 11 | Follows screen + ViewModel | FollowsScreen, FollowsViewModel | 0.5 day |
| 12 | Player screen | PlayerScreen, BiliPlayer | 2 days |
| 13 | Settings screen | SettingsScreen | 0.5 day |
| 14 | Integration testing + polish | All files | 2 days |
| **Total** | | | **~12 days** |

## File Count Summary

- Build/config: 3 files
- Data models: 6 files
- Network: 4 files
- Repository: 3 files
- DataStore: 2 files
- UI screens: 9 files (screen + viewmodel pairs)
- UI components: 3 files
- Player: 1 file
- Navigation: 1 file
- App/Activity: 2 files
- Utility: 2 files
- **Total: ~36 files**

## D-pad Key Mapping (PlayerScreen)

| Key | Action |
|---|---|
| D-pad Center / Enter | Play / Pause |
| D-pad Left | Seek backward 10s |
| D-pad Right | Seek forward 10s |
| D-pad Up | Show quality selector |
| D-pad Down | Show settings menu |
| Back | Exit player |

## Testing Strategy

- Manual testing on Android TV emulator
- Test login flow with real Bilibili account
- Test all three feed types load correctly
- Test video playback with DASH streams
- Test D-pad navigation throughout app
