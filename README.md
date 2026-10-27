# PieDrop

**中文** | [English](README.en.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

**Drop Finder-selected files into running AI CLI sessions — macOS menu bar utility**

**一键把 Finder 选中的文件路径投递进终端 AI CLI 会话的 macOS 菜单栏工具**

![Release](https://img.shields.io/github/v/release/Ezreal777/PieDrop) ![License](https://img.shields.io/badge/license-MIT-blue) ![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black) ![Arch](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-lightgrey)

<p align="center">
  <img src="docs/screenshot.png" width="680" alt="PieDrop 光环模式面板：左侧磨砂圆盘按 CLI 着色列出正在运行的会话（qodercli / codex），右侧是该会话的结构化卡片">
</p>

用 Claude Code、Codex CLI、Gemini CLI 这类 AI 编程工具时，经常要让 AI 处理刚在 Finder 里看到的文件：手动敲一长串路径太累，把文件拖进终端会带出转义字符，复制路径再粘贴又要来回切窗口。PieDrop 把这件事变成一步——

**Finder 选中文件 → 按快捷键 → 弹出圆盘列出正在运行的 CLI 会话 → 点一下目标扇区**，路径就追加进那个会话的输入框（光标处插入，不自动发送）。

## 适用场景

- **给 AI 会话追加文件上下文**：Claude Code / Codex / qodercli 对话里快速引用 Finder 中的代码、设计稿、日志、数据文件
- **多会话并行**：同时开着多个 agent 会话时，hover 预览每个会话正在做的任务，精准选择投递目标
- **终端命令引用文件**：空闲的 zsh / bash / fish 终端也能投，写 `cat`、`open`、`grep` 命令时不用再打路径

## 特性

- **光环模式**：磨砂玻璃「左圆右方」面板，左侧是按 CLI 着色的扇区圆盘，右侧是当前会话的结构化卡片（任务缩略 / 终端 / 未发送草稿）
- **菜单模式**：紧凑列表样式，hover 展开详情
- **草稿感知排序**：有未发送输入的会话在列表中置顶、在圆盘中获得更大的扇区角度，多会话并行时一眼锁定"正等你输入"的那个
- **会话发现**：`ps` 扫描 agent 进程 × 终端窗口按 TTY 精确配对，空闲 shell 终端也能投递
- **双通道注入**：iTerm2 直接 write text（免聚焦）；Terminal.app 剪贴板 + 模拟 ⌘V
- **可自定义**：快捷键（默认 ⌃⌥F）、开机自启、面板样式，都在菜单栏图标里调整
- **双架构**：Apple Silicon 与 Intel Mac 通用（universal binary）
- **本地运行**：无网络访问、无数据收集、无后台服务

## 支持的会话

qodercli、claude、codex、gemini、aider、qwen、opencode、crush，以及 zsh / bash / fish 空闲终端。

## 系统要求

- macOS 13+
- Swift 5.9 工具链（`swift build`）

## 安装

从 [Releases](https://github.com/Ezreal777/PieDrop/releases) 下载最新的 `PieDrop-x.y.z.dmg`，打开后把 PieDrop 拖进 Applications；或用 Homebrew：

```bash
brew install --cask ezreal777/tap/pie-drop
# 首次安装会提示信任第三方 tap，按提示确认即可
```

### 首次打开提示「无法验证开发者」？

项目用自建证书签名（没有付费开发者账号），首次打开需要手动放行一次：

1. 双击 PieDrop，提示无法验证时点「完成」
2. 打开 系统设置 → 隐私与安全性，底部会出现「PieDrop 已被阻止」，点「仍要打开」
3. 按启动提示授权 辅助功能 与 自动化（Finder / 终端）权限，之后即可正常使用

## 构建与安装

```bash
git clone https://github.com/Ezreal777/PieDrop
cd PieDrop
./scripts/build-app.sh              # 开发模式：构建并安装到 /Applications
./scripts/build-app.sh --release    # 发布模式：产出 universal DMG 到 dist/
```

### 签名说明

脚本优先使用钥匙串里名为 **PieDrop Dev** 的自建代码签名证书（Keychain Access → 证书助理 → 创建证书，类型选「代码签名」）。用固定证书签名后，重新编译不会丢失系统授权；没有证书时回退 ad-hoc 签名，每次重新编译后需要在「系统设置 → 隐私与安全性」里重新授权。

## 首次运行授权

| 权限 | 用途 |
| --- | --- |
| 辅助功能 | 向 Terminal.app 模拟 ⌘V 粘贴路径 |
| 自动化（Finder） | 读取当前选中的文件 |
| 自动化（Terminal / iTerm2） | 定位会话窗口、写入输入框 |

App 完全本地运行：不上网、不收集数据；草稿预览只读取终端屏幕尾部最后一条未发送输入。

## 使用

1. 在 Finder 选中一个或多个文件
2. 按快捷键（默认 ⌃⌥F，可在菜单栏自定义）
3. hover 扇区预览会话卡片，点击投递；Esc 或点击面板外关闭
4. 菜单栏图标里可切换样式 / 快捷键 / 开机自启

免权限预览 UI：

```bash
/Applications/PieDrop.app/Contents/MacOS/PieDrop --demo
# --demo-at X,Y 可把面板固定弹在指定全局坐标（截图 / 演示用）
```

## 项目结构

```
Sources/PieDrop/
  main.swift              入口 + 菜单栏（样式 / 快捷键 / 自启）
  SessionDetector.swift   会话发现（ps × TTY 配对）
  DiskPanel.swift         面板形状 / 布局 / 控制器
  DialView.swift          圆盘扇区（恒定缝宽）
  PreviewCard.swift       右侧结构化卡片
  MenuList.swift          菜单列表模式
  Injector.swift          路径注入（iTerm2 / Terminal 双通道）
  DraftReader.swift       未发送草稿读取
  FinderSelection.swift   Finder 选区
  HotKey.swift            全局热键注册
  Hotkeys.swift           快捷键持久化与展示
  HotkeyRecorder.swift    快捷键录制面板
  UICommon.swift          调色板 / Toast / 工具
  ScriptRunner.swift      AppleScript / shell 执行
scripts/
  build-app.sh            构建 + 签名 + 安装
  make-icon.swift         生成应用图标
```

## 许可证

[MIT](LICENSE)
