# BiliBili tvOS 客户端

> 在 Apple TV 上享受完整的 B站体验

**本项目没有任何授权的 Testflight 发放以及任何收费版本，请注意辨别安全性。**

---

## 功能特性

### 核心功能
| 功能 | 说明 |
|------|------|
| 直播 | 实时弹幕、清晰度切换 |
| 视频 | 推荐/热门/排行榜、弹幕防挡、HDR/杜比视界 |
| 搜索 | 热搜榜、历史记录、分页加载 |
| 个人 | 历史记录、稍后再看、关注、收藏、投稿 |
| 投屏 | 云视听小电视协议支持 |

### 增强特性 (Fork 新增)
- **智能搜索** - B站热搜榜 + 搜索历史 + 无限滚动分页
- **播放增强** - 循环模式、跳过片头片尾 (SponsorBlock)
- **稳定性优化** - 安全模式防崩溃、错误处理增强

---

## 截图

**QR码登录** - 扫码快速登录
<p align="center">
  <img src="https://dissidia.oss-cn-beijing.aliyuncs.com/test/20260109/atv_bilibili_screenshot_1.png" width="60%" />
</p>

**内容浏览** - 直播、推荐、热门、排行榜
<p align="center">
  <img src="https://dissidia.oss-cn-beijing.aliyuncs.com/test/20260109/simulator_screenshot_apple_tv_4k_3rd_gen_20260109_224442.jpg" width="45%" />
  <img src="https://dissidia.oss-cn-beijing.aliyuncs.com/test/20260109/atv_bilibili_screenshot_2.png" width="45%" />
</p>

**番剧影视** & **播放设置**
<p align="center">
  <img src="https://dissidia.oss-cn-beijing.aliyuncs.com/test/20260109/simulator_screenshot_apple_tv_4k_3rd_gen_20260109_225658.png" width="45%" />
  <img src="https://dissidia.oss-cn-beijing.aliyuncs.com/test/20260109/simulator_screenshot_apple_tv_4k_3rd_gen_20260109_225450.jpg" width="45%" />
</p>

---

## 安装

### 未签名 IPA
从 [Releases](https://github.com/yichengchen/ATV-Bilibili-demo/releases/tag/nightly) 下载，使用 Sideloadly 或 AltStore 安装。

### 源码编译
```bash
# 克隆仓库
git clone https://github.com/yichengchen/ATV-Bilibili-demo.git
cd ATV-Bilibili-demo

# 使用 Fastlane 构建
fastlane build_unsign_ipa
```

---

## 社区

- Telegram: https://t.me/appletvbilibilidemo

---

## 致谢

- [thmatuza/MPEGDASHAVPlayerDemo](https://github.com/thmatuza/MPEGDASHAVPlayerDemo)
- [dreamCodeMan/B-webmask](https://github.com/dreamCodeMan/B-webmask)
- [分析Bilibili客户端的"哔哩必连"协议](https://xfangfang.github.io/028)
- App Icon: [【22娘×33娘】亲爱的UP主，你怎么还在咕咕咕？](https://www.bilibili.com/video/BV1AB4y1k7em)
