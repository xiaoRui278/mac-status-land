# Mac Status Land

> **Vibe Coding 实现** — 本项目完全由 AI（Claude）生成，通过自然语言描述需求，AI 自动完成架构设计、代码实现和文档编写。

一个 macOS 菜单栏应用，用于管理被刘海屏遮挡的状态栏图标。

## 功能

- 自动发现第三方应用的状态栏图标
- 隐藏/显示图标
- 点击弹出窗口显示隐藏的图标
- 自定义隐藏规则
- 开机自动启动
- 状态持久化

## 系统要求

- macOS 12.0 (Monterey) 或更高版本
- Xcode 14.0 或更高版本（用于编译）

## 安装

### 从源码编译

```bash
git clone git@github.com:xiaoRui278/mac-status-bar-land.git
cd mac-status-bar-land/MacStatusLand
swift run
```

### 权限设置

首次运行时，应用会请求以下权限：

1. **辅助功能**：用于读取和操控状态栏图标
2. **屏幕录制**：用于截取状态栏图标图像

请在系统设置中授权。

## 使用方法

1. 启动应用后，会在菜单栏显示图标（`›`）
2. 左键点击图标：显示/隐藏 Popover 窗口
3. 右键点击图标：显示菜单（退出）
4. 在 Popover 中点击图标：触发原图标的点击事件

### ⚠️ 重要提示

**建议将 MacStatusLand 图标拖动到菜单栏最右侧**，防止应用自身的图标被刘海屏遮挡。

操作方法：按住 `⌘ Command` 键，用鼠标拖动图标到最右侧位置。

## 技术栈

- Swift 5.9+
- SwiftUI
- AppKit
- Accessibility API
- CoreGraphics (CGEvent + CGWindowListCreateImage)

## 架构

```
MacStatusLand/
├── Services/
│   ├── AccessibilityService.swift   # Accessibility API 封装
│   ├── IconDiscoveryService.swift   # 图标发现服务
│   ├── IconScreenshotService.swift  # 图标截图服务
│   ├── IconHidingService.swift      # 图标隐藏/显示
│   ├── PersistenceService.swift     # 数据持久化
│   └── LoginItemService.swift       # 开机自启
├── ViewModels/
│   └── MenuBarViewModel.swift       # 状态管理
├── Views/
│   ├── PopoverView.swift            # 弹出窗口
│   ├── SettingsView.swift           # 设置界面
│   └── PermissionView.swift         # 权限引导
└── Models/
    ├── MenuBarApp.swift             # 应用数据模型
    └── AppSettings.swift            # 设置数据模型
```

## 技术细节

### 状态栏图标操控

macOS 没有公开 API 可以直接移动状态栏图标。所有状态栏管理应用（如 Bartender、Hidden Bar）都使用相同的技术：

1. 使用 Accessibility API 发现和读取图标信息
2. 使用 CGEvent 模拟 Cmd+drag 来移动图标
3. 状态栏图标由 SystemUIServer 托管

### 权限要求

- **辅助功能**：用于读取和操控状态栏图标
- **屏幕录制**：用于截取图标图像
- **沙盒**：必须禁用（Accessibility API 不支持沙盒）

## 许可证

MIT License
