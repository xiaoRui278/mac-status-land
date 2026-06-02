# Mac Status Land

<p align="center">
  <img src="images/AppIcon.png" width="100" alt="MacStatusLand Icon">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange?logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue?logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/AI-Vibe%20Coding-purple" alt="AI Vibe Coding">
</p>

<p align="center">
  <strong>一个 macOS 菜单栏应用，用于管理被刘海屏遮挡的状态栏图标</strong>
</p>

---

## ✨ 功能特点

- 🔍 **自动发现** — 自动扫描第三方应用的状态栏图标
- 🖱️ **一键触发** — 点击图标直接打开原应用界面
- 🎯 **精准识别** — 显示应用图标和名称
- ⚙️ **丰富设置** — 开机启动、自动刷新、中英文切换
- 🌙 **深色模式** — 完美支持 macOS 深色/浅色模式

## 📸 界面预览

<p align="center">
  <img src="images/PopOver.jpg" width="280" alt="PopOver 界面">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="images/设置.png" width="300" alt="设置界面">
</p>

## 🚀 快速开始

### 系统要求

| 要求 | 版本 |
|------|------|
| macOS | 13.0 (Ventura) 或更高 |

### 安装

#### 方式一：Homebrew（推荐）

```bash
brew install xiaoRui278/tap/macstatusland
```

#### 方式二：下载 DMG

1. 前往 [Releases](https://github.com/xiaoRui278/mac-status-land/releases) 下载最新版本
2. 打开 DMG，将 MacStatusLand.app 拖到 Applications
3. 首次运行需要在 **系统设置 → 隐私与安全性 → 辅助功能** 中授权

#### 方式三：从源码编译

```bash
git clone git@github.com:xiaoRui278/mac-status-land.git
cd mac-status-land/MacStatusLand
swift run
```

### 权限设置

首次运行时，应用会请求以下权限：

| 权限 | 用途 | 必需 |
|------|------|------|
| 辅助功能 | 读取和触发状态栏图标点击 | ✅ |

> 💡 **提示**：请在 **系统设置 → 隐私与安全性 → 辅助功能** 中授权。

### ⚠️ 更新后需要重新授权

由于 macOS 安全机制，每次更新应用后，辅助功能权限会失效。这是 macOS 的正常行为，不是应用 Bug。

**重新授权步骤**：
1. 打开 **系统设置 → 隐私与安全性 → 辅助功能**
2. **删除**列表中的 MacStatusLand 条目
3. **重新打开** MacStatusLand 应用
4. 在弹出的权限请求中点击 **打开系统设置**
5. **重新勾选** MacStatusLand

> 💡 **为什么需要这样做？**
> macOS 将辅助功能权限绑定到应用的代码签名。由于 MacStatusLand 是开源项目，使用临时签名（ad-hoc），每次更新后签名会变化，导致权限失效。这是 macOS 保护用户安全的机制。

## 📖 使用方法

1. 启动应用后，菜单栏会显示 `›` 图标
2. **左键点击** — 显示 Popover 窗口，列出所有第三方应用图标
3. **右键点击** — 显示菜单（设置、退出）
4. **点击图标** — 直接打开对应应用的界面

### ⚠️ 重要提示

**建议将 MacStatusLand 图标拖动到菜单栏最右侧**，防止应用自身的图标被刘海屏遮挡。

> 操作方法：按住 `⌘ Command` 键，用鼠标拖动图标到最右侧位置。

## ⚙️ 设置功能

右键点击状态栏图标 → 设置，可以配置：

| 设置项 | 说明 |
|--------|------|
| 开机启动 | 登录时自动启动应用 |
| 自动刷新 | 定时刷新图标列表（15/30/60/120 秒） |
| 显示系统应用 | 是否显示 Apple 系统应用图标 |
| 失焦自动关闭 | 切换应用时自动关闭 Popover |
| 全局快捷键 | 配置快捷键切换 Popover |
| 语言 | 切换中文/英文界面 |

## 🏗️ 技术架构

```
MacStatusLand/
├── Services/
│   ├── AccessibilityService.swift    # Accessibility API 封装
│   ├── IconDiscoveryService.swift    # 图标发现服务
│   ├── SettingsService.swift         # 设置服务
│   └── StringLocalization.swift      # 本地化支持
├── Views/
│   ├── MenuBarPopoverView.swift      # Popover 界面
│   └── SettingsView.swift            # 设置界面
├── StatusBarController.swift         # 状态栏控制器
└── MacStatusLandApp.swift            # 应用入口
```

### 技术栈

| 技术 | 用途 |
|------|------|
| Swift / SwiftUI | 主要开发语言和 UI 框架 |
| AppKit | macOS 原生组件 |
| Accessibility API | 读取状态栏图标信息 |
| AXUIElementPerformAction | 触发图标点击事件 |

### 工作原理

1. **发现图标** — 使用 Accessibility API 扫描 `AXExtrasMenuBar` 获取所有状态栏图标
2. **获取信息** — 读取每个图标的 `AXTitle`、`AXDescription`、`AXIdentifier`
3. **显示图标** — 优先使用应用图标，SF Symbol 作为备选
4. **触发点击** — 使用 `AXUIElementPerformAction(kAXPressAction)` 直接触发原图标动作

## 📝 更新日志

### v1.0.0 (2025-06-01)
- ✅ 初始发布
- ✅ 支持第三方应用图标发现和点击
- ✅ 支持设置功能（开机启动、自动刷新、语言切换）
- ✅ 支持 macOS 深色模式
- ✅ 使用 Accessibility API 直接触发点击

## 📄 许可证

MIT License © [xiaoRui278](https://github.com/xiaoRui278)

---

<p align="center">
  <sub>Made with ❤️ and AI (Vibe Coding)</sub>
</p>
