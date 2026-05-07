# MarkPlay

**专注本地视频书签的 macOS 原生播放器。**

MarkPlay 的目标不是再造一个通用播放器，而是把 *“本地视频 + 时间点书签 + 跳转复看 + 导出整理”* 这条工作流做扎实。它适合需要反复回看视频片段的人——课程复盘、访谈整理、研究笔记、剪辑素材标记，或者从 Windows PotPlayer 切换到 Mac、依赖书签管理的用户。

## 为什么用 MarkPlay

- **打书签零打扰**：按 `Cmd + B` 立刻在当前播放时间生成书签，命名时视频不会被暂停。
- **书签即工作流**：右侧边栏一目了然，可点击跳转、就地重命名、删除、CSV 导出。
- **每个视频都记得你**：书签按视频自动保存，下次打开同一个文件，书签自动恢复。
- **macOS 原生体验**：SwiftUI + AVFoundation + SwiftData，启动快，资源占用低，深色界面与系统一致。
- **简单可控**：1.0 不做字幕、不做缩略图、不做在线流，只把核心闭环做稳。

## 核心功能

- 打开本地 `mp4`、`mov`、`m4v` 文件，支持窗口拖入
- 播放、暂停、进度跳转、音量、静音、全屏
- 0.1x 步进的播放速度调节，区间 0.1x – 3.0x
- 任意时间点添加书签，inline 命名，无阻塞
- 右侧书签管理器：浏览、跳转、重命名、删除
- 全屏下书签管理器以辅助栏形式呈现
- 按视频持久化：再次打开自动恢复书签
- 一键导出当前视频书签为 CSV

## 系统要求

- macOS 14.0 Sonoma 或更高版本
- Apple Silicon Mac（主要测试平台）
- Intel Mac 理论可用，但未做完整验证

## 安装

### 方式一：下载已打包的 DMG（推荐普通用户）

1. 在 [Releases](../../releases) 页面下载最新版 `MarkPlay.dmg`。
2. 双击打开 DMG，将 `MarkPlay.app` 拖进 `Applications` 文件夹。
3. 首次打开时，macOS Gatekeeper 可能提示“无法验证开发者”：
   - 在 `Applications` 中**右键** `MarkPlay.app`，选择**打开**，再次确认即可。
   - 或在系统设置 → 隐私与安全性 → “仍要打开”里放行。

> 当前发布的是未签名、未公证的本地分发包。如果你对未签名应用有顾虑，可以选择从源码构建。

### 方式二：从源码构建（推荐开发者）

需要 Xcode 或 Xcode Command Line Tools，Swift 6.0 工具链。

```bash
git clone https://github.com/<your-account>/mark-play.git
cd mark-play
./script/build_and_run.sh
```

可用模式：

| 命令 | 作用 |
| --- | --- |
| `./script/build_and_run.sh` | 构建并启动 |
| `./script/build_and_run.sh --build-only` | 仅生成 `dist/MarkPlay.app` |
| `./script/build_and_run.sh --verify` | 构建并校验进程启动 |
| `./script/build_and_run.sh --logs` | 启动并跟随系统日志 |
| `./script/build_and_run.sh --debug` | 在 lldb 中启动 |

### 自行打包 DMG

```bash
./scripts/package-release.sh
```

输出位于 `release/MarkPlay.dmg`，可直接作为 GitHub Release 附件。生产分发请使用 Apple Developer ID 证书完成签名与公证（notarization），否则 Gatekeeper 会拦截首次打开。

## 快速上手

1. `Cmd + O` 打开视频，或直接把 `mp4` / `mov` / `m4v` 拖入窗口。
2. 播放过程中按 `Cmd + B` 在当前时间打书签。
3. 右侧书签管理器：单击跳转、双击重命名、删除按钮移除。
4. `Cmd + E` 导出当前视频的全部书签为 CSV。
5. 关闭窗口下次再打开，书签自动恢复。

## 快捷键速查

| 快捷键 | 功能 |
| --- | --- |
| `Cmd + O` | 打开视频 |
| `Space` | 播放 / 暂停 |
| `Left` / `Right` | 快退 / 快进 5 秒 |
| `Cmd + Left` / `Cmd + Right` | 快退 / 快进 30 秒 |
| `Up` / `Down` | 调整音量 |
| `M` | 静音切换 |
| `Cmd + [` / `Cmd + ]` | 播放速度 -0.1x / +0.1x |
| `Cmd + 0` | 恢复 1.0x 速度 |
| `Cmd + B` | 添加书签 |
| `Cmd + Shift + B` | 显示 / 隐藏书签管理器 |
| `Cmd + E` | 导出书签为 CSV |
| `Control + Cmd + F` | 全屏 |

## 项目结构

```text
Sources/markplay/
  Models/        SwiftData 数据模型（VideoRecord、Bookmark）
  ViewModels/    PlayerViewModel、BookmarkViewModel
  Views/         SwiftUI 界面（ContentView、PlayerControlsView、BookmarkSidebarView 等）
  Services/      视频识别、CSV 导出
  Utilities/     时间格式化等工具
  Resources/     图标源文件

Tests/markplayTests/   单元测试

script/build_and_run.sh         本地构建与运行
scripts/build-app.sh            构建 .app 包
scripts/package-release.sh      生成发布用 DMG
```

## 路线图

- 1.0 已覆盖：本地播放、书签 CRUD、自动持久化、CSV 导出。
- 暂不计划：字幕、缩略图书签、自定义快捷键、在线 / 流媒体、复杂素材库。
- 兼容更多容器（mkv、avi、ts 等）需要 mpv / VLCKit / FFmpeg 路线，不会混入 1.x。

## 反馈与贡献

欢迎在 [Issues](../../issues) 提交 Bug、功能建议或使用反馈。提 PR 前请确保 `swift build` 与 `swift test` 通过。

## 许可

本项目使用 [PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0) 协议授权：

- **非商业使用**（个人学习、研究、爱好项目、教育与非营利组织、公益用途等）：可自由使用、修改、分发，保留版权声明即可。
- **商业使用**：需要单独获得作者授权。请通过 [Issues](../../issues) 留言或邮件说明用途，作者会回复授权细节。

完整条款见仓库根目录的 [`LICENSE`](LICENSE) 文件。
