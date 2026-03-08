## Project Overview

tvOS (Apple TV) client for the BiliBili video streaming platform. Written in Swift 5.0+, targeting tvOS 16.0+. Unsigned IPA builds are distributed via GitHub Releases (nightly tag).

## Build Commands

```bash
# Build for tvOS Simulator
fastlane build_simulator

# Build unsigned IPA for Apple TV
fastlane build_unsign_ipa
```

There is no test suite. Build verification happens through the Xcode project. Use Xcode directly for development and debugging.

## Architecture

The app uses a layered architecture with a factory-based navigation system:

**Entry Point:** `AppDelegate.swift` checks login state and routes to either `LoginViewController` (QR code auth) or `BLTabBarViewController`.

**Module Layer** (`BilibiliLive/Module/`) — Feature-specific view controllers:
- `Tabbar/` — Root navigation; `BLTabBarViewController` uses `TabBarPageFactory` to create tab VCs dynamically based on user-customizable ordering
- `Live/` — Live stream playback with `LiveDanMuProvider` for real-time danmaku over WebSocket + Brotli decompression
- `Personal/` — User account, search, follows, history, settings, tab customization
- `ViewController/` — Feed, hot, favorites, rankings
- `DLNA/` — UPnP Digital Media Renderer (`BiliBiliUpnpDMR`) for casting

**Component Layer** (`BilibiliLive/Component/`) — Reusable subsystems:
- `Player/` — `CommonPlayerViewController` is the base player. `BilibiliVideoResourceLoaderDelegate` implements custom MPEG-DASH resource loading (fetches manifests, parses SIDX segments, rewrites URLs for AVPlayer)
- `Video/` — `VideoPlayerViewController` + `VideoPlayerViewModel` for regular video; `VideoDanmuProvider` + `VideoDanmuFilter` for video danmaku; `MaskProvider/` for danmaku anti-blocking
- `Feed/` — `FeedCollectionViewController` / `FeedCollectionViewCell` for content discovery grids
- `CommonPlayer/` — Local SPM package with shared player utilities

**Request Layer** (`BilibiliLive/Request/`) — All API communication:
- `WebRequest.swift` — Core HTTP layer (Alamofire-based)
- `WebRequest+WbiSign.swift` — Request signing extension
- `ApiRequest.swift` — Endpoint definitions, token refresh, MD5 signing, error handling (code `-101` = token expired)
- `dm.pb.swift` / `dmView.pb.swift` — Protobuf models for danmaku
- `CookieManager.swift` — Session/cookie persistence

**Account Management:** `AccountManager.swift` handles multi-account state and session tokens.

**Vendor:** `DanmakuKit/` (danmaku rendering engine), `PocketSVG/` (SVG parsing).

## Key Dependencies (SPM)

- `Alamofire` — HTTP networking
- `SwiftyJSON` — JSON parsing
- `SwiftProtobuf` — Danmaku protocol buffers
- `Kingfisher` — Image caching
- `SnapKit` — Auto-layout
- `CocoaLumberjack` / `CocoaLumberjackSwift` — Logging
- `CocoaAsyncSocket` — TCP/UDP for DLNA
- `Gzip` — Compression
- `Swifter` (custom fork) — HTTP server for casting receiver

## Reusable UI Components (`Component/View/`)

All interactive cells and buttons are built for tvOS focus engine — expect scale/parallax animations on focus as a baseline.

**`BLButton`** — Base `UIControl` with blur background and focus-driven parallax + shadow. Use `onPrimaryAction` callback instead of `addTarget`.
- **`BLCustomButton`** — Adds image + title label below, `isOn` toggle state, three image states (default / on / highlighted). IBDesignable.
- **`BLCustomTextButton`** — Text-only variant; changes color on focus. Carries an optional `object: Any?` for associated data.

**`BLMotionCollectionViewCell`** — Base `UICollectionViewCell` providing parallax tilt + scale-on-focus. All feed/settings cells subclass this. Override `setup()` for layout and set `scaleFactor` for zoom intensity.
- **`BLSettingLineCollectionViewCell`** — Horizontal card, 40pt font, exposes `makeLayout()` static method returning a ready-made `NSCollectionLayoutSection` (70pt height, 0.9 group width).
- **`BLTextOnlyCollectionViewCell`** — Dark blur card, centered multi-line label. scaleFactor = 1.15.

**`BLOverlayView`** — Gradient overlay for feed cards. Call `configure(_ overlay: DisplayOverlay)` with left/right `DisplayOverlayItem` arrays (SF Symbol icon + text) and an optional colored badge. Used inside `FeedCollectionViewCell`.

## Feed System (`Component/Feed/`)

**`FeedCollectionViewController`** — Generic paginated feed controller backed by `UICollectionViewDiffableDataSource`.

Key points for subclassing / use:
- Items conform to **`DisplayData`** protocol: `title`, `ownerName`, `pic` (required); `avatar`, `date`, `overlay: DisplayOverlay?` (optional).
- Use **`AnyDispplayData`** (type-erased wrapper) to mix heterogeneous `DisplayData` types in one feed.
- Set `displayDatas` to replace content (auto-deduplicates); call `appendData(displayData:)` for pagination.
- Auto-triggers `loadMore` callback when <12 items remain.
- Attach a `customHeaderConfig: FeedHeaderConfig` for section headers.
- Override `FeedDisplayStyle` per instance: `.large` (3 cols), `.normal` (4 cols), `.sideBar` (3 cols narrow).

**`StandardVideoCollectionViewController`** — Preferred base class for any video list screen. Generic over `PlayableData` (= `DisplayData` + `aid`/`cid`). Override `request(page:) async` to supply data; the base class handles pagination, 60-minute auto-reload, and navigation to `VideoDetailViewController` on selection. Adjust `reloadInterval` if needed.

**`FeedCollectionViewCell`** — 16:9 image card with `BLOverlayView`, optional avatar, `MarqueeLabel` title (auto-scrolls when focused), creator + date line. Images loaded via Kingfisher at 360×202. Set `onLongPress` for context menus.

## Player Plugin Architecture (`Component/Player/`)

**`CommonPlayerViewController`** wraps `AVPlayerViewController` and owns a list of `CommonPlayerPlugin` objects.

```swift
playerVC.addPlugin(plugin: MyPlugin())
playerVC.updateMenus()   // rebuilds AVPlayerViewController info panel menus from all plugins
```

**`CommonPlayerPlugin`** protocol — all methods have empty default implementations, so adopt only what you need:

| Method | When called |
|---|---|
| `playerDidLoad(playerVC:)` | Player container appeared |
| `playerDidChange(player:)` | AVPlayer instance swapped |
| `playerItemDidChange(playerItem:)` | New AVPlayerItem loaded |
| `playerWillStart` / `playerDidStart` | Playback begins |
| `playerDidPause` / `playerDidEnd` / `playerDidFail` | State transitions |
| `playerDidCleanUp` | Player teardown |
| `addViewToPlayerOverlay(container:)` | Add UI on top of video |
| `addMenuItems(current:)` | Contribute items to info panel menu |

**Existing plugins** (all in `Component/Player/`):

| Plugin | Purpose |
|---|---|
| `URLPlayPlugin` | Sets up AVPlayer from URL with custom HTTP headers; `isLive` flag disables stall recovery |
| `DanmuViewPlugin` | Renders danmaku via `DanmakuKit`; requires a `DanmuProviderProtocol`; adds menu items for visibility, duration (4/6/8s), AI filter level |
| `SpeedChangerPlugin` | Playback speed (0.5×–2×) with pitch correction; persists to `Settings.mediaPlayerSpeed` |
| `SponsorSkipPlugin` | Fetches SponsorBlock segments; two modes: auto-jump (5s preview) or manual tip button |
| `MaskViewPlugin` | Delivers pixel buffers for danmaku anti-blocking masks via `MaskProvider` |
| `DebugPlugin` | Overlay with bitrate, stall count, dropped frames; toggled via info panel menu |

**Settings** (`Settings.swift`) — Global user preferences accessed via `@UserDefault` / `@UserDefaultCodable` property wrappers. Observable values (e.g. `Defaults.shared.$showDanmu`) integrate with Combine for reactive UI.

## Important Patterns

- **DASH Playback:** `BilibiliVideoResourceLoaderDelegate` intercepts `bilibili://` scheme URLs registered with AVPlayer, fetches real DASH manifests from Bilibili API, and serves segments. This is the core of video playback quality selection.
- **Danmaku:** Video danmaku uses Protobuf (`dm.pb.swift`); live danmaku uses a custom WebSocket protocol with Brotli-compressed payloads parsed in `LiveDanMuProvider`.
- **Request Signing:** API calls require both MD5 signing (`ApiRequest`) and WBI signing (`WebRequest+WbiSign`). Unsigned requests will fail with auth errors.
- **Tab Customization:** Tab order is stored in `UserDefaults` and read by `BLTabBarViewController` via the factory pattern at launch.
