# OpenFiles — Filza 风格 iOS 文件管理器

一个 SwiftUI 编写的 Filza 风格文件管理器，支持在越狱 iOS 设备上浏览**沙盒外**全盘文件。

## 功能

- 📂 目录浏览：文件/文件夹列表，按类型显示图标，大小与修改时间
- 🌐 全盘访问：`/`、`/var/mobile`、App 沙盒容器、Bundle 目录（越狱设备）
- 🔍 QuickLook 预览：文本 / 图片 / 视频 / PDF / 压缩包等
- ✏️ 文件操作：复制、移动、删除、重命名、新建文件/文件夹、分享导出
- 🛡️ 环境自适应：自动检测越狱与全盘权限；未越狱时优雅降级为沙盒内浏览

## ⚠️ 关于"沙盒外访问"的重要说明

iOS 的沙盒是系统级安全机制。要在沙盒外浏览（像 Filza 那样），需要**同时满足**：

1. **设备已越狱**（Filza 本身也只发布在 Sileo/Cydia，就是这个原因）
2. App 的签名里包含 `com.apple.private.security.no-container` entitlement
3. 该 entitlement 必须由平台信任的签名授权（如越狱环境中的 ldid 假签名 + 放行补丁）

未越狱设备上，任何 App（包括本工程）都无法读取自己的沙盒以外的路径，这是硬件级强制，无代码层面的绕过方式。本项目在未越狱时会显示环境状态页并降级为沙盒内浏览。

## 构建（需要 Mac + Xcode）

```bash
# 1. 安装 XcodeGen（生成 .xcodeproj）
brew install xcodegen

# 2. 生成工程
cd OpenFiles
xcodegen generate

# 3. 打开并编译
open OpenFiles.xcodeproj
# Xcode 中选择目标设备，Cmd+R 运行
```

### 越狱设备安装

1. Xcode 顶部选择你的设备，`Product → Archive`，导出 ipa
2. 若走侧载（AltStore/TrollStore）：
   - **TrollStore**（推荐，iOS 14–16.x / 部分设备支持到更高）：TrollStore 安装 ipa 时会自动以合法方式保留 entitlements，全盘访问可直接生效
   - 越狱设备（Dopamine / palera1n 等）：安装后用 `ldid -S` 重签：
     ```bash
     ldid -SOpenFiles.entitlements /var/containers/Bundle/Application/<UUID>/OpenFiles.app/OpenFiles
   - 或直接打包成 deb 发到自己的 Sileo 源

## 项目结构

```
OpenFiles/
├── project.yml              # XcodeGen 工程定义（含 entitlements）
├── OpenFiles.entitlements   # 越狱全盘访问声明
└── Sources/
    ├── OpenFilesApp.swift   # 入口
    ├── RootView.swift       # 主导航 + 环境状态页
    ├── FileSystem.swift     # 文件系统访问层（含越狱探测、降级逻辑）
    └── BrowserView.swift    # 浏览器界面、预览、新建/重命名/分享
```

## 环境探测逻辑（FileSystem.swift）

- 检查 Cydia / Sileo / /var/lib/dpkg / /var/jb / .bootstrapped 判断越狱
- 越狱时尝试 `contentsOfDirectory("/")` 探测 entitlements 是否真正生效
- 全盘不可用时，位置列表只显示应用自己的 Documents 目录
