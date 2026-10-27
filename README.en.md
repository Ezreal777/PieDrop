[中文](README.md) | **English** | [日本語](README.ja.md) | [한국어](README.ko.md)

# PieDrop

**Drop Finder-selected files into running AI CLI sessions — macOS menu bar utility**

![Release](https://img.shields.io/github/v/release/Ezreal777/PieDrop) ![License](https://img.shields.io/badge/license-MIT-blue) ![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black) ![Arch](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-lightgrey)

<p align="center">
  <img src="docs/screenshot.png" width="680" alt="PieDrop halo panel: a frosted dial on the left lists running CLI sessions (qodercli / codex), a structured session card on the right">
</p>

When working with AI coding tools like Claude Code, Codex CLI, or Gemini CLI, you often need the AI to handle a file you just spotted in Finder: typing a long path by hand is tedious, dragging the file into the terminal injects escaped characters, and copy-pasting means switching windows back and forth. PieDrop turns it into a single step —

**Select files in Finder → press the hotkey → a dial pops up listing your running CLI sessions → click the target sector**, and the path is appended to that session's input box (inserted at the cursor, never auto-sent).

## Use cases

- **Add file context to AI sessions**: quickly reference code, designs, logs, or data files from Finder in Claude Code / Codex / qodercli conversations
- **Parallel sessions**: hover to preview each session's current task and pick the exact target when running multiple agents
- **Reference files in shell commands**: idle zsh / bash / fish terminals work too — no more typing paths for `cat`, `open`, `grep`

## Features

- **Halo mode**: frosted-glass "circle + card" panel — a dial of CLI-colored sectors on the left, a structured session card (task / terminal / unsent draft) on the right
- **Menu mode**: compact list style that expands on hover
- **Draft-aware ordering**: sessions with unsent input float to the top of the list and take a larger sector in the dial — spot the one waiting for your input at a glance
- **Session discovery**: `ps` scan for agent processes paired with terminal windows by TTY; idle shells work too
- **Dual-channel injection**: iTerm2 write text (no focus needed); Terminal.app via clipboard + simulated ⌘V
- **Customizable**: hotkey (default ⌃⌥F), launch at login, panel style — all from the menu bar icon
- **Universal binary**: Apple Silicon and Intel Macs
- **Local only**: no network access, no data collection, no background services

## Supported sessions

qodercli, claude, codex, gemini, aider, qwen, opencode, crush, plus idle zsh / bash / fish terminals.

## Requirements

- macOS 13+
- Swift 5.9 toolchain (`swift build`)

## Install

Download the latest `PieDrop-x.y.z.dmg` from [Releases](https://github.com/Ezreal777/PieDrop/releases) and drag PieDrop into Applications, or use Homebrew:

```bash
brew install --cask ezreal777/tap/pie-drop
# Homebrew will ask you to trust this third-party tap on first install
```

### "Unidentified developer" on first launch?

The app is signed with a self-created certificate (no paid Apple Developer account), so the first launch needs a one-time manual approval:

1. Double-click PieDrop; when warned about the developer, click "Done"
2. Open System Settings → Privacy & Security, find the PieDrop entry near the bottom, click "Open Anyway"
3. Grant Accessibility and Automation (Finder / terminal) permissions when prompted

## Build & install

```bash
git clone https://github.com/Ezreal777/PieDrop
cd PieDrop
./scripts/build-app.sh              # dev mode: build and install to /Applications
./scripts/build-app.sh --release    # release mode: universal DMG into dist/
```

### Signing

The script prefers a self-created code-signing certificate named **PieDrop Dev** in your keychain (Keychain Access → Certificate Assistant → Create Certificate, type "Code Signing"). With a fixed certificate, rebuilds keep your system permissions; without one, it falls back to ad-hoc signing and you need to re-approve in System Settings after each rebuild.

## First-run permissions

| Permission | Purpose |
| --- | --- |
| Accessibility | Simulate ⌘V into Terminal.app |
| Automation (Finder) | Read the current Finder selection |
| Automation (Terminal / iTerm2) | Locate session windows, write into the input box |

Everything runs locally: no network access, no data collection; the draft preview only reads the last unsent line at the tail of the terminal screen.

## Usage

1. Select one or more files in Finder
2. Press the hotkey (default ⌃⌥F, customizable from the menu bar)
3. Hover a sector to preview the session card, click to deliver; Esc or click outside to dismiss
4. Switch style / hotkey / launch-at-login from the menu bar icon

Preview the UI without granting any permissions:

```bash
/Applications/PieDrop.app/Contents/MacOS/PieDrop --demo
# --demo-at X,Y pins the panel at fixed global coordinates (for screenshots / demos)
```

## Project structure

```
Sources/PieDrop/
  main.swift              Entry point + menu bar (style / hotkey / login item)
  SessionDetector.swift   Session discovery (ps × TTY pairing)
  DiskPanel.swift         Panel shape / layout / controller
  DialView.swift          Dial sectors (constant-width gaps)
  PreviewCard.swift       Structured side card
  MenuList.swift          Menu list mode
  Injector.swift          Path injection (iTerm2 / Terminal channels)
  DraftReader.swift       Unsent draft reading
  FinderSelection.swift   Finder selection
  HotKey.swift            Global hotkey registration
  Hotkeys.swift           Hotkey persistence & display
  HotkeyRecorder.swift    Hotkey recorder panel
  UICommon.swift          Palette / toast / utilities
  ScriptRunner.swift      AppleScript / shell execution
scripts/
  build-app.sh            Build + sign + install
  make-icon.swift         Generate the app icon
```

## License

[MIT](LICENSE)
