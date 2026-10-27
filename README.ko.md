[中文](README.md) | [English](README.en.md) | [日本語](README.ja.md) | **한국어**

# PieDrop

**Finder에서 선택한 파일을 실행 중인 AI CLI 세션에 한 번에 전달하는 macOS 메뉴 막대 도구**

![Release](https://img.shields.io/github/v/release/Ezreal777/PieDrop) ![License](https://img.shields.io/badge/license-MIT-blue) ![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black) ![Arch](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-lightgrey)

<p align="center">
  <img src="docs/screenshot.png" width="680" alt="PieDrop Halo 패널: 왼쪽 프로스트 글래스 다이얼에 실행 중인 CLI 세션(qodercli / codex)이 표시되고, 오른쪽에 세션의 구조화된 카드가 표시됨">
</p>

Claude Code, Codex CLI, Gemini CLI 같은 AI 코딩 도구를 쓰다 보면 Finder에서 방금 본 파일을 AI에게 처리시키고 싶은 순간이 자주 있습니다. 긴 경로를 직접 입력하기는 번거롭고, 파일을 터미널로 드래그하면 이스케이프 문자가 섞이고, 복사해서 붙여넣으려면 창을 오가야 하죠. PieDrop은 이 과정을 한 단계로 줄입니다 —

**Finder에서 파일 선택 → 단축키 입력 → 실행 중인 CLI 세션이 다이얼에 표시 → 대상 섹터 클릭**. 그러면 경로가 해당 세션의 입력창에 추가됩니다(커서 위치에 삽입, 자동 전송 없음).

## 활용 사례

- **AI 세션에 파일 컨텍스트 추가**: Claude Code / Codex / qodercli 대화에서 Finder의 코드, 디자인 시안, 로그, 데이터 파일을 빠르게 참조
- **여러 세션 병행**: 에이전트를 여러 개 돌릴 때 호버로 각 세션의 현재 작업을 미리 보고 정확한 대상을 선택
- **셸 명령에서 파일 참조**: 빈 zsh / bash / fish 터미널에도 전달 가능. `cat`, `open`, `grep`에 경로를 일일이 입력할 필요 없음

## 특징

- **Halo 모드**: 프로스트 글래스 "원형 + 카드" 패널 — 왼쪽은 CLI별 색상 섹터 다이얼, 오른쪽은 세션의 구조화된 카드(작업 / 터미널 / 전송 전 임시 입력)
- **메뉴 모드**: 컴팩트한 리스트 스타일, 호버하면 상세 펼침
- **세션 탐색**: `ps`로 에이전트 프로세스를 스캔해 터미널 창과 TTY 기준으로 정확히 매칭, 빈 셸도 지원
- **이중 주입 채널**: iTerm2는 write text로 직접 주입(포커스 불필요), Terminal.app는 클립보드 + ⌘V 시뮬레이션
- **커스터마이즈**: 단축키(기본 ⌃⌥F), 로그인 시 실행, 패널 스타일 — 모두 메뉴 막대 아이콘에서
- **유니버설 바이너리**: Apple Silicon과 Intel Mac 모두 지원
- **완전 로컬**: 네트워크 접근 없음, 데이터 수집 없음, 백그라운드 서비스 없음

## 지원 세션

qodercli, claude, codex, gemini, aider, qwen, opencode, crush, 그리고 빈 상태의 zsh / bash / fish 터미널.

## 시스템 요구 사항

- macOS 13 이상
- Swift 5.9 툴체인 (`swift build`)

## 설치

[Releases](https://github.com/Ezreal777/PieDrop/releases)에서 최신 `PieDrop-x.y.z.dmg`를 다운로드해 PieDrop을 Applications로 드래그하거나, Homebrew를 사용하세요:

```bash
brew install --cask ezreal777/tap/pie-drop
# 첫 설치 시 서드파티 tap 신뢰 여부를 물어봅니다
```

### 첫 실행 시 "개발자를 확인할 수 없음"이 표시되면

이 앱은 자체 생성한 인증서로 서명되어 있습니다(유료 Apple Developer 계정 없음). 첫 실행 때 한 번만 수동 승인이 필요합니다:

1. PieDrop을 더블클릭하고, 경고가 뜨면 "완료" 클릭
2. 시스템 설정 → 개인정보 보호 및 보안을 열고, 하단의 PieDrop 항목에서 "실행" 클릭
3. 안내에 따라 손쉬운 사용 및 자동화(Finder / 터미널) 권한 허용

## 빌드 및 설치

```bash
git clone https://github.com/Ezreal777/PieDrop
cd PieDrop
./scripts/build-app.sh              # 개발 모드: 빌드 후 /Applications에 설치
./scripts/build-app.sh --release    # 릴리스 모드: 유니버설 DMG를 dist/에 생성
```

### 서명

스크립트는 키체인에 있는 **PieDrop Dev**라는 자체 생성 코드 서명 인증서를 우선 사용합니다(키체인 접근 → 인증서 지원 → 인증서 생성, 유형 "코드 서명"). 고정 인증서를 사용하면 다시 빌드해도 시스템 권한이 유지됩니다. 인증서가 없으면 ad-hoc 서명으로 대체되며, 빌드할 때마다 시스템 설정에서 다시 승인해야 합니다.

## 첫 실행 권한

| 권한 | 용도 |
| --- | --- |
| 손쉬운 사용 | Terminal.app에 ⌘V 시뮬레이션 |
| 자동화 (Finder) | 현재 Finder 선택 항목 읽기 |
| 자동화 (Terminal / iTerm2) | 세션 창 위치 파악 및 입력창 쓰기 |

모든 동작은 로컬에서 이루어집니다: 네트워크 접근 없음, 데이터 수집 없음. 임시 입력 미리보기는 터미널 화면 끝의 마지막 미전송 입력 한 줄만 읽습니다.

## 사용 방법

1. Finder에서 파일을 하나 이상 선택
2. 단축키 입력(기본 ⌃⌥F, 메뉴 막대에서 변경 가능)
3. 섹터에 호버하면 세션 카드 미리 보기, 클릭하면 전달. Esc 또는 패널 밖 클릭으로 닫기
4. 메뉴 막대 아이콘에서 스타일 / 단축키 / 로그인 시 실행 전환

권한을 하나도 허용하지 않고 UI 미리 보기:

```bash
/Applications/PieDrop.app/Contents/MacOS/PieDrop --demo
# --demo-at X,Y 로 패널을 지정 좌표에 고정 표시(스크린샷 / 데모용)
```

## 프로젝트 구조

```
Sources/PieDrop/
  main.swift              엔트리 포인트 + 메뉴 막대(스타일 / 단축키 / 로그인 실행)
  SessionDetector.swift   세션 탐색 (ps × TTY 매칭)
  DiskPanel.swift         패널 형상 / 레이아웃 / 컨트롤러
  DialView.swift          다이얼 섹터 (일정 폭 간격)
  PreviewCard.swift       구조화된 사이드 카드
  MenuList.swift          메뉴 리스트 모드
  Injector.swift          경로 주입 (iTerm2 / Terminal 이중 채널)
  DraftReader.swift       전송 전 임시 입력 읽기
  FinderSelection.swift   Finder 선택 항목
  HotKey.swift            전역 단축키 등록
  Hotkeys.swift           단축키 저장 및 표시
  HotkeyRecorder.swift    단축키 녹화 패널
  UICommon.swift          팔레트 / 토스트 / 유틸리티
  ScriptRunner.swift      AppleScript / shell 실행
scripts/
  build-app.sh            빌드 + 서명 + 설치
  make-icon.swift         앱 아이콘 생성
```

## 라이선스

[MIT](LICENSE)
