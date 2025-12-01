# TestFlight 部署指南

本文档指导如何将 BilibiliLive tvOS 应用打包并发布到 TestFlight。

## 前置要求

- macOS 电脑（已安装 Xcode 15.0+）
- Apple Developer Program 个人/企业账号（$99/年）
- 不需要 Apple TV 设备

## 快速开始

### 方式一：使用自动化脚本（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/DISSIDIA-986/ATV-Bilibili-demo.git
cd ATV-Bilibili-demo

# 2. 运行部署脚本
./scripts/testflight_deploy.sh
```

脚本会引导你完成所有步骤。

### 方式二：手动操作

按照以下步骤手动完成。

---

## 详细步骤

### 第一步：在 App Store Connect 创建 App

1. 登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 点击「我的 App」→「+」→「新建 App」
3. 填写信息：
   - **平台**: 勾选 `tvOS`
   - **名称**: `BilibiliLive`（或自定义名称）
   - **主要语言**: `简体中文`
   - **Bundle ID**: 选择「注册新的 Bundle ID」或使用已有的
   - **SKU**: `com.yourname.bilibililivetv`（唯一标识）

### 第二步：在 Xcode 配置签名

1. 打开项目：
   ```bash
   open BilibiliLive.xcodeproj
   ```

2. 选择 `BilibiliLive` Target → `Signing & Capabilities`

3. 配置签名：
   - **Team**: 选择你的开发者账号
   - **Bundle Identifier**: 改为你在 App Store Connect 创建的 Bundle ID
   - 勾选 `Automatically manage signing`

4. 确保没有签名错误（红色警告）

### 第三步：配置版本号

1. 在 Xcode 中选择 `BilibiliLive` Target → `General`
2. 设置：
   - **Version**: `1.0.0`（每次提交 TestFlight 需要递增）
   - **Build**: `1`（同一版本下每次上传需要递增）

### 第四步：构建 Archive

1. 在 Xcode 菜单选择：`Product` → `Destination` → `Any tvOS Device (arm64)`

2. 清理项目：`Product` → `Clean Build Folder` (⇧⌘K)

3. 构建 Archive：`Product` → `Archive` (⇧⌘B 可能需要先 Build)

   或使用命令行：
   ```bash
   xcodebuild -project BilibiliLive.xcodeproj \
              -scheme BilibiliLive \
              -destination "generic/platform=tvOS" \
              -archivePath ./build/BilibiliLive.xcarchive \
              archive
   ```

4. 等待构建完成（约 3-5 分钟）

### 第五步：上传到 App Store Connect

**方式 A：使用 Xcode Organizer（推荐新手）**

1. Archive 完成后会自动打开 Organizer（或 `Window` → `Organizer`）
2. 选择刚才的 Archive → 点击 `Distribute App`
3. 选择 `TestFlight & App Store Connect` → `Next`
4. 选择 `Upload` → `Next`
5. 保持默认选项 → `Next`
6. 选择签名证书 → `Upload`
7. 等待上传完成

**方式 B：使用命令行**

```bash
# 导出 IPA
xcodebuild -exportArchive \
           -archivePath ./build/BilibiliLive.xcarchive \
           -exportPath ./build \
           -exportOptionsPlist ./scripts/ExportOptions.plist

# 上传到 App Store Connect
xcrun altool --upload-app \
             -f ./build/BilibiliLive.ipa \
             -t tvos \
             -u "your_apple_id@example.com" \
             -p "app-specific-password"
```

> 注意：需要在 Apple ID 设置中生成「App 专用密码」

### 第六步：在 TestFlight 中配置

1. 上传成功后，登录 [App Store Connect](https://appstoreconnect.apple.com)
2. 进入你的 App → `TestFlight` 标签
3. 等待 Apple 处理（通常 10-30 分钟）
4. 处理完成后，点击构建版本旁的「管理」
5. 填写「测试须知」（可简单填写）

### 第七步：邀请测试者

**内部测试（最多 100 人，无需审核）**

1. `TestFlight` → `内部测试` → `App Store Connect 用户`
2. 点击 `+` 添加测试者（需要是你团队的成员）

**外部测试（最多 10,000 人，首次需审核）**

1. `TestFlight` → `外部测试` → 点击 `+` 创建群组
2. 命名群组（如「Beta 测试」）
3. 添加构建版本
4. 添加测试者：输入邮箱地址
5. 首次提交外部测试需要 Apple 审核（1-2 天）

### 第八步：测试者安装

测试者会收到邮件邀请：

1. 在 Apple TV 上下载 `TestFlight` App
2. 打开 TestFlight，使用收到邀请的 Apple ID 登录
3. 接受邀请并安装 App

---

## 常见问题

### Q: Bundle ID 冲突怎么办？
A: Bundle ID 全球唯一，如果被占用，换一个即可，如 `com.yourname.bilibili.tv`

### Q: 上传后一直显示「正在处理」？
A: 通常需要 10-30 分钟，如果超过 1 小时，检查邮箱是否有 Apple 的错误通知

### Q: 外部测试审核被拒？
A: TestFlight 审核比 App Store 宽松，但仍需遵守基本规范。常见原因：
- 缺少登录演示账号
- 崩溃或严重 bug
- 描述与功能不符

### Q: 如何更新版本？
A: 递增 Build 号 → 重新 Archive → 上传 → 在 TestFlight 选择新版本

### Q: 没有 Apple TV 如何测试？
A: 可以使用 Xcode 的 tvOS Simulator 进行基本测试：
```bash
open -a Simulator
# 选择 tvOS 设备
```

---

## 邀请测试者信息模板

发送给测试者的信息：

```
我已将 BilibiliLive (哔哩哔哩 Apple TV 客户端) 发布到 TestFlight。

安装步骤：
1. 在 Apple TV 上下载「TestFlight」App
2. 打开 TestFlight，用你的 Apple ID 登录
3. 查看并接受邀请，点击安装

你的 Apple ID 邮箱：[填写测试者邮箱]

注意：TestFlight 版本有效期 90 天，届时需要更新。
```

---

## 联系方式

如有问题，请在 GitHub 提 Issue：
https://github.com/DISSIDIA-986/ATV-Bilibili-demo/issues
