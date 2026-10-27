[中文](README.md) | [English](README.en.md) | **日本語** | [한국어](README.ko.md)

# PieDrop

**Finder で選択したファイルを、動作中の AI CLI セッションにワンクリックで投入する macOS メニューバーツール**

![Release](https://img.shields.io/github/v/release/Ezreal777/PieDrop) ![License](https://img.shields.io/badge/license-MIT-blue) ![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black) ![Arch](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-lightgrey)

<p align="center">
  <img src="docs/screenshot.png" width="680" alt="PieDrop のハローモードパネル：左側のすりガラス風ダイヤルに実行中の CLI セッション（qodercli / codex）が表示され、右側にセッションの構造化カードが表示される">
</p>

Claude Code、Codex CLI、Gemini CLI などの AI コーディングツールを使っていると、Finder で見つけたファイルを AI に処理してほしい場面がよくあります。長いパスを手打ちするのは面倒で、ファイルをターミナルにドラッグするとエスケープ文字が混ざり、コピー＆ペーストはウィンドウを行き来するはめに。PieDrop はこれを一歩にまとめます——

**Finder でファイルを選択 → ホットキーを押す → 実行中の CLI セッションがダイヤルに表示される → 目的のセクタをクリック**。するとパスがそのセッションの入力欄に追記されます（カーソル位置に挿入、自動送信はしません）。

## 活用シーン

- **AI セッションへのファイルコンテキスト追加**：Claude Code / Codex / qodercli の会話で、コード・デザインカンプ・ログ・データファイルをすばやく参照
- **並行セッション**：複数の agent を同時実行中でも、ホバーで各セッションのタスクをプレビューし、正確に投げ先を選択
- **シェルコマンドでのファイル参照**：空きの zsh / bash / fish ターミナルにも投入可能。`cat`、`open`、`grep` のパス打ちが不要に

## 特徴

- **ハローモード**：すりガラス風の「円 + カード」パネル。左側は CLI ごとの色分きセクタダイヤル、右側はセッションの構造化カード（タスク / ターミナル / 未送信の下書き）
- **メニューモード**：コンパクトなリスト表示。ホバーで詳細を展開
- **セッション検出**：`ps` で agent プロセスを走査し、ターミナルウィンドウと TTY で正確にペアリング。空きシェルも対象
- **二重注入チャネル**：iTerm2 は write text で直接注入（フォーカス不要）。Terminal.app はクリップボード + ⌘V シミュレート
- **カスタマイズ可能**：ホットキー（デフォルト ⌃⌥F）、ログイン時に起動、パネルスタイル——すべてメニューバーアイコンから
- **ユニバーサルバイナリ**：Apple Silicon と Intel Mac の両対応
- **ローカル完結**：ネットワークアクセスなし・データ収集なし・バックグラウンドサービスなし

## 対応セッション

qodercli、claude、codex、gemini、aider、qwen、opencode、crush、および空き状態の zsh / bash / fish ターミナル。

## 動作環境

- macOS 13 以上
- Swift 5.9 ツールチェーン（`swift build`）

## インストール

[Releases](https://github.com/Ezreal777/PieDrop/releases) から最新の `PieDrop-x.y.z.dmg` をダウンロードして PieDrop を Applications にドラッグするか、Homebrew を利用：

```bash
brew install --cask ezreal777/tap/pie-drop
# 初回インストール時にサードパーティ tap の信頼を求められます
```

### 初回起動で「開発元を検証できない」と表示される

本アプリは自己作成の証明書で署名しています（有料の Apple Developer アカウントなし）。初回起動時に一度だけ手動で許可が必要です：

1. PieDrop をダブルクリックし、警告が出たら「完了」をクリック
2. システム設定 → プライバシーとセキュリティ を開き、下部の PieDrop の項目で「このまま開く」をクリック
3. 起動時の案内に従い、アクセシビリティとオートメーション（Finder / ターミナル）の権限を許可

## ビルドとインストール

```bash
git clone https://github.com/Ezreal777/PieDrop
cd PieDrop
./scripts/build-app.sh              # 開発モード：ビルドして /Applications にインストール
./scripts/build-app.sh --release    # リリースモード：ユニバーサル DMG を dist/ に生成
```

### 署名について

スクリプトは、キーチェーン内の **PieDrop Dev** という自己作成のコード署名証明書を優先します（キーチェーンアクセス → 証明書アシスタント → 証明書を作成、種類は「コード署名」）。固定の証明書を使えば再ビルドしてもシステム権限は失われません。証明書がない場合は ad-hoc 署名にフォールバックし、再ビルドのたびにシステム設定で再許可が必要になります。

## 初回起動時の権限

| 権限 | 用途 |
| --- | --- |
| アクセシビリティ | Terminal.app への ⌘V シミュレート |
| オートメーション（Finder） | 現在の Finder 選択項目の読み取り |
| オートメーション（Terminal / iTerm2） | セッションウィンドウの特定と入力欄への書き込み |

すべてローカルで動作：ネットワークアクセスなし、データ収集なし。下書きプレビューはターミナル画面末尾の未送信入力の最終行を読むだけです。

## 使い方

1. Finder でファイルを 1 つ以上選択
2. ホットキーを押す（デフォルト ⌃⌥F、メニューバーから変更可能）
3. セクタにホバーしてセッションカードをプレビュー、クリックで投入。Esc またはパネル外クリックで閉じる
4. メニューバーアイコンからスタイル / ホットキー / ログイン時起動を切り替え

権限を一切許可せずに UI をプレビュー：

```bash
/Applications/PieDrop.app/Contents/MacOS/PieDrop --demo
# --demo-at X,Y でパネルを指定座標に固定表示（スクリーンショット / デモ用）
```

## プロジェクト構成

```
Sources/PieDrop/
  main.swift              エントリポイント + メニューバー（スタイル / ホットキー / ログイン起動）
  SessionDetector.swift   セッション検出（ps × TTY ペアリング）
  DiskPanel.swift         パネル形状 / レイアウト / コントローラ
  DialView.swift          ダイヤルセクタ（等幅ギャップ）
  PreviewCard.swift       構造化サイドカード
  MenuList.swift          メニューリストモード
  Injector.swift          パス注入（iTerm2 / Terminal の二重チャネル）
  DraftReader.swift       未送信ドラフトの読み取り
  FinderSelection.swift   Finder 選択項目
  HotKey.swift            グローバルホットキー登録
  Hotkeys.swift           ホットキーの永続化と表示
  HotkeyRecorder.swift    ホットキー録画パネル
  UICommon.swift          パレット / トースト / ユーティリティ
  ScriptRunner.swift      AppleScript / shell 実行
scripts/
  build-app.sh            ビルド + 署名 + インストール
  make-icon.swift         アプリアイコンの生成
```

## ライセンス

[MIT](LICENSE)
