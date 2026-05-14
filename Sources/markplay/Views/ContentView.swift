import AVKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var bookmarkViewModel: BookmarkViewModel
    @EnvironmentObject private var playlistViewModel: PlaylistViewModel
    @State private var isSidebarVisible = true
    @State private var sidebarWasVisibleBeforeFullscreen = true
    @State private var isFullscreenSidebarVisible = false
    @State private var isFullscreen = false
    @State private var areControlsVisible = true
    @State private var sidebarWidth: CGFloat = 320
    @State private var isDropTargeted = false
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var playerHUD: PlayerHUDState?
    @State private var hideHUDTask: Task<Void, Never>?

    var body: some View {
        mainLayout
        .ignoresSafeArea(.container, edges: .top)
        .background(
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.055, green: 0.060, blue: 0.072)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(WindowConfigurator())
        .background(
            KeyCommandView { event in
                handleKeyDown(event)
            }
        )
        .onAppear {
            bookmarkViewModel.bind(record: playerViewModel.currentRecord, context: modelContext)
            playerViewModel.onPlaybackEnded = {
                playlistViewModel.playNext(context: modelContext, playerViewModel: playerViewModel)
            }
            syncTrafficLightVisibility()
        }
        .onChange(of: playerViewModel.currentRecord) { _, record in
            bookmarkViewModel.bind(record: record, context: modelContext)
        }
        .onChange(of: playerViewModel.currentURL) { _, url in
            hideControlsTask?.cancel()
            hideHUDTask?.cancel()
            playerHUD = nil
            withAnimation(.easeOut(duration: 0.16)) {
                areControlsVisible = true
            }
            syncTrafficLightVisibility()
            if url != nil {
                scheduleControlsHide()
            }
        }
        .onChange(of: areControlsVisible) { _, _ in
            syncTrafficLightVisibility()
        }
        .onChange(of: isFullscreen) { _, _ in
            syncTrafficLightVisibility()
        }
        .onChange(of: playerViewModel.isPlaying) { _, isPlaying in
            guard playerViewModel.currentURL != nil else {
                return
            }
            showPlayerHUD(
                title: isPlaying ? "播放" : "暂停",
                detail: String(format: "%.1fx", playerViewModel.playbackRate),
                systemImage: isPlaying ? "play.fill" : "pause.fill"
            )
        }
        .onChange(of: playerViewModel.playbackRate) { _, rate in
            guard playerViewModel.currentURL != nil else {
                return
            }
            showPlayerHUD(
                title: String(format: "%.1fx", rate),
                detail: "播放速度",
                systemImage: "speedometer"
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            syncTrafficLightVisibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            syncTrafficLightVisibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            sidebarWasVisibleBeforeFullscreen = isSidebarVisible
            isFullscreenSidebarVisible = false
            withAnimation(.snappy(duration: 0.2)) {
                isFullscreen = true
                areControlsVisible = true
            }
            scheduleControlsHide()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            hideControlsTask?.cancel()
            withAnimation(.snappy(duration: 0.2)) {
                isFullscreen = false
                isSidebarVisible = sidebarWasVisibleBeforeFullscreen
                isFullscreenSidebarVisible = false
                areControlsVisible = true
            }
            syncTrafficLightVisibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            closeCurrentSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appCommand)) { notification in
            guard let command = notification.object as? AppCommandAction else {
                return
            }
            handle(command)
        }
        .onDrop(of: [.movie, .mpeg4Movie, .quickTimeMovie, .audio, .mp3, .fileURL, .url], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .background(
            FileDropBridge(
                isTargeted: $isDropTargeted,
                onDrop: handleInputURLs
            )
        )
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.accentColor, lineWidth: 4)
                    .allowsHitTesting(false)
            }
        }
        .alert("提示", isPresented: errorBinding) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(playerViewModel.errorMessage ?? bookmarkViewModel.exportErrorMessage ?? playlistViewModel.errorMessage ?? "")
        }
        .confirmationDialog("删除当前视频的全部书签？", isPresented: $bookmarkViewModel.showDeleteAllConfirmation) {
            Button("删除全部", role: .destructive) {
                bookmarkViewModel.deleteAll()
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $bookmarkViewModel.isNamingBookmark) {
            BookmarkNamingView(
                name: $bookmarkViewModel.pendingBookmarkName,
                timeText: bookmarkViewModel.pendingBookmarkTimeText,
                onConfirm: {
                    bookmarkViewModel.confirmPendingBookmark()
                },
                onCancel: {
                    bookmarkViewModel.cancelPendingBookmark()
                }
            )
        }
    }

    private var mainLayout: some View {
        HStack(spacing: 0) {
            videoStage

            if shouldShowInlineSidebar {
                SidebarResizeHandle(width: $sidebarWidth)
                BookmarkSidebarView(style: sidebarStyle)
                    .frame(width: currentSidebarWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(Color.black)
    }

    private var videoStage: some View {
        ZStack(alignment: .bottom) {
            VideoPlayerView()
                .overlay(alignment: .center) {
                    if playerViewModel.currentURL == nil {
                        EmptyVideoState(onOpenMedia: openMedia)
                    }
                }

            if playerViewModel.currentURL != nil {
                MouseTrackingView {
                    showControls()
                } onMouseDown: {
                    endBookmarkEditingAndFocusPlayer()
                } onDoubleClick: {
                    endBookmarkEditingAndFocusPlayer()
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
            }

            if shouldShowControls {
                PlayerControlsView(isOverlay: true)
                    .padding(.horizontal, isFullscreen ? 24 : 16)
                    .padding(.vertical, isFullscreen ? 18 : 12)
                    .background(controlBackground)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if let cue = playerViewModel.activeSubtitleCue {
                SubtitleOverlayText(text: cue.text)
                    .padding(.horizontal, isFullscreen ? 34 : 24)
                    .padding(.bottom, subtitleBottomPadding)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if let playerHUD {
                PlayerStatusHUD(state: playerHUD)
                    .padding(.top, isFullscreen ? 24 : 18)
                    .padding(.leading, isFullscreen ? 24 : 18)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.black)
        .contextMenu {
            PlayerContextMenu(
                isSidebarVisible: isFullscreen ? isFullscreenSidebarVisible : isSidebarVisible,
                onToggleSidebar: toggleBookmarkSidebar
            )
        }
    }

    private var shouldShowControls: Bool {
        playerViewModel.currentURL == nil || areControlsVisible
    }

    private var controlBackground: some ShapeStyle {
        AnyShapeStyle(.black.opacity(isFullscreen ? 0.62 : 0.72))
    }

    private var subtitleBottomPadding: CGFloat {
        if shouldShowControls {
            return isFullscreen ? 104 : 84
        }
        return isFullscreen ? 34 : 22
    }

    private var shouldShowInlineSidebar: Bool {
        isFullscreen ? isFullscreenSidebarVisible : isSidebarVisible
    }

    private var sidebarStyle: BookmarkSidebarStyle {
        isFullscreen ? .inspector : .sidebar
    }

    private var currentSidebarWidth: CGFloat {
        isFullscreen ? fullscreenInspectorWidth : sidebarWidth
    }

    private var fullscreenInspectorWidth: CGFloat {
        min(max(sidebarWidth, SidebarLayout.inspectorMinWidth), SidebarLayout.inspectorMaxWidth)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: {
                playerViewModel.errorMessage != nil ||
                    bookmarkViewModel.exportErrorMessage != nil ||
                    playlistViewModel.errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    playerViewModel.errorMessage = nil
                    bookmarkViewModel.exportErrorMessage = nil
                    playlistViewModel.errorMessage = nil
                }
            }
        )
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        let accumulator = DroppedURLAccumulator()

        for (index, provider) in providers.enumerated() {
            if let itemTypeIdentifier = dropItemTypeIdentifier(for: provider) {
                group.enter()
                provider.loadItem(forTypeIdentifier: itemTypeIdentifier, options: nil) { item, _ in
                    if let url = droppedURL(from: item) {
                        accumulator.append(url, at: index)
                    }
                    group.leave()
                }
            } else if let fileTypeIdentifier = dropFileRepresentationTypeIdentifier(for: provider) {
                group.enter()
                provider.loadInPlaceFileRepresentation(forTypeIdentifier: fileTypeIdentifier) { url, _, _ in
                    if let url {
                        accumulator.append(url, at: index)
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            let urls = accumulator.urlsInOriginalOrder()
            if urls.isEmpty {
                playlistViewModel.errorMessage = "拖入内容没有可读取的文件路径。"
            } else {
                handleInputURLs(urls)
            }
        }
        return true
    }

    private func dropItemTypeIdentifier(for provider: NSItemProvider) -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return UTType.fileURL.identifier
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            return UTType.url.identifier
        }

        return nil
    }

    private func dropFileRepresentationTypeIdentifier(for provider: NSItemProvider) -> String? {
        let fileTypes: [UTType] = [
            .mp3,
            .audio,
            .mpeg4Movie,
            .quickTimeMovie,
            .movie
        ]

        return fileTypes
            .map(\.identifier)
            .first { provider.hasItemConformingToTypeIdentifier($0) }
    }

    private func openMedia() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie, .movie, .mp3]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else {
            return
        }

        handleInputURLs(panel.urls)
    }

    private func openPlaylistFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.mp3]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else {
            return
        }

        playlistViewModel.append(urls: panel.urls, context: modelContext, playerViewModel: playerViewModel)
    }

    private func openPlaylistFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        guard panel.runModal() == .OK else {
            return
        }

        playlistViewModel.append(urls: panel.urls, context: modelContext, playerViewModel: playerViewModel)
    }

    private func handle(_ command: AppCommandAction) {
        switch command {
        case .openVideo:
            openMedia()
        case .openPlaylistFiles:
            openPlaylistFiles()
        case .openPlaylistFolder:
            openPlaylistFolder()
        case .exportBookmarks:
            bookmarkViewModel.exportCSV()
        case .togglePlayback:
            playerViewModel.togglePlayback()
        case .skipBackward:
            skip(by: -5)
        case .skipForward:
            skip(by: 5)
        case .skipBackward30:
            skip(by: -30)
        case .skipForward30:
            skip(by: 30)
        case .volumeUp:
            playerViewModel.changeVolume(by: 0.05)
        case .volumeDown:
            playerViewModel.changeVolume(by: -0.05)
        case .toggleMute:
            playerViewModel.toggleMute()
        case .speedDown:
            playerViewModel.changePlaybackRate(by: -0.1)
        case .speedUp:
            playerViewModel.changePlaybackRate(by: 0.1)
        case .speedReset:
            playerViewModel.resetPlaybackRate()
        case .toggleFullscreen:
            NSApp.keyWindow?.toggleFullScreen(nil)
        case .addBookmark:
            bookmarkViewModel.beginBookmarkNaming(at: playerViewModel.currentTime)
        case .toggleBookmarkSidebar:
            toggleBookmarkSidebar()
        case .deleteAllBookmarks:
            bookmarkViewModel.showDeleteAllConfirmation = true
        }
    }

    private func handleInputURLs(_ urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        let playlistURLs = urls.filter { isMP3($0) || isDirectory($0) }
        if !playlistURLs.isEmpty {
            playlistViewModel.append(urls: playlistURLs, context: modelContext, playerViewModel: playerViewModel)
            return
        }

        if urls.count == 1, let url = urls.first {
            playlistViewModel.currentItemID = nil
            playerViewModel.openMedia(url: url, context: modelContext)
        } else {
            playerViewModel.errorMessage = "一次只能直接打开一个非 MP3 媒体文件。"
        }
    }

    private func isMP3(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "mp3"
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    private func handleKeyDown(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.isEmpty else {
            return
        }

        switch event.keyCode {
        case 36, 76:
            if shouldShowInlineSidebar, let selectedBookmarkID = bookmarkViewModel.selectedBookmarkID {
                if let bookmark = bookmarkViewModel.sortedBookmarks.first(where: { $0.id == selectedBookmarkID }) {
                    bookmarkViewModel.beginEditing(bookmark)
                }
                return
            }

            guard !isFullscreen else {
                return
            }
            NSApp.keyWindow?.toggleFullScreen(nil)
        case 49:
            playerViewModel.togglePlayback()
        case 53:
            if isFullscreen {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
        case 123:
            skip(by: -5)
        case 124:
            skip(by: 5)
        case 125:
            playerViewModel.changeVolume(by: -0.05)
        case 126:
            playerViewModel.changeVolume(by: 0.05)
        default:
            if event.charactersIgnoringModifiers?.lowercased() == "m" {
                playerViewModel.toggleMute()
            }
        }
    }

    private func skip(by delta: Double) {
        playerViewModel.skip(by: delta)
        let seconds = Int(abs(delta))
        showPlayerHUD(
            title: delta > 0 ? "快进 \(seconds) 秒" : "快退 \(seconds) 秒",
            detail: TimeFormatter.hms(playerViewModel.currentTime),
            systemImage: delta > 0 ? "goforward.\(seconds)" : "gobackward.\(seconds)"
        )
    }

    private func toggleBookmarkSidebar() {
        withAnimation(.snappy(duration: 0.2)) {
            if isFullscreen {
                isFullscreenSidebarVisible.toggle()
                areControlsVisible = true
                scheduleControlsHide()
            } else {
                isSidebarVisible.toggle()
            }
        }
    }

    private func showPlayerHUD(title: String, detail: String, systemImage: String) {
        hideHUDTask?.cancel()
        withAnimation(.easeOut(duration: 0.12)) {
            playerHUD = PlayerHUDState(title: title, detail: detail, systemImage: systemImage)
        }
        hideHUDTask = Task {
            try? await Task.sleep(for: .seconds(1.05))
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.22)) {
                    playerHUD = nil
                }
            }
        }
    }

    private func endBookmarkEditingAndFocusPlayer() {
        bookmarkViewModel.finishEditingBookmark()
        bookmarkViewModel.selectedBookmarkID = nil
        KeyCommandNSView.focusCurrent()
    }

    private func closeCurrentSession() {
        hideControlsTask?.cancel()
        hideHUDTask?.cancel()
        playerHUD = nil
        playerViewModel.stopAndClear()
        bookmarkViewModel.clearSession()
    }

    private func showControls() {
        withAnimation(.easeOut(duration: 0.16)) {
            areControlsVisible = true
        }
        syncTrafficLightVisibility()
        scheduleControlsHide()
    }

    private func scheduleControlsHide() {
        hideControlsTask?.cancel()
        guard playerViewModel.currentURL != nil else {
            return
        }

        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.22)) {
                    areControlsVisible = false
                }
                syncTrafficLightVisibility()
            }
        }
    }

    private func syncTrafficLightVisibility() {
        guard !isFullscreen else {
            return
        }
        guard let window = NSApp.mainWindow ?? NSApp.keyWindow ?? NSApp.windows.first else {
            return
        }
        let hidden = !shouldShowControls
        for buttonType in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            guard let button = window.standardWindowButton(buttonType) else {
                continue
            }
            button.isHidden = hidden
            button.alphaValue = hidden ? 0 : 1
        }
    }
}

private enum SidebarLayout {
    static let minWidth: CGFloat = 220
    static let maxWidth: CGFloat = 460
    static let inspectorMinWidth: CGFloat = 240
    static let inspectorMaxWidth: CGFloat = 360
}

private struct BookmarkNamingView: View {
    @Binding var name: String
    let timeText: String
    @FocusState private var isFocused: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("添加书签")
                    .font(.title3.weight(.semibold))
                Text("输入名称后确认，书签会保存到当前视频。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("名称")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("书签名称", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .onSubmit(onConfirm)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("时间")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(timeText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(timeText, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("复制时间")

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                    )
                }
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("添加", action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 380)
        .onAppear {
            isFocused = true
        }
    }
}

private struct PlayerHUDState: Equatable {
    let title: String
    let detail: String
    let systemImage: String
}

private struct PlayerStatusHUD: View {
    let state: PlayerHUDState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
                Text(state.detail)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.68))
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.26), radius: 16, y: 8)
        .allowsHitTesting(false)
    }
}

private struct SubtitleOverlayText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.white)
            .lineLimit(3)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: 920)
            .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 18, y: 7)
            .allowsHitTesting(false)
    }
}

private struct EmptyVideoState: View {
    let onOpenMedia: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.square")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.86))
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )

            VStack(spacing: 4) {
                Text("打开本地媒体")
                    .font(.title3.weight(.semibold))

                Text("拖入媒体、MP3 或文件夹，或点击下方按钮选择文件")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.62))
            }
            .multilineTextAlignment(.center)

            Button(action: onOpenMedia) {
                Text("打开媒体")
                    .frame(minWidth: 112)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("也可使用 Cmd+O")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.46))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

private struct PlayerContextMenu: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var bookmarkViewModel: BookmarkViewModel

    let isSidebarVisible: Bool
    let onToggleSidebar: () -> Void

    var body: some View {
        Button(playerViewModel.isPlaying ? "暂停" : "播放") {
            playerViewModel.togglePlayback()
        }

        Button("添加书签...") {
            bookmarkViewModel.beginBookmarkNaming(at: playerViewModel.currentTime)
        }
        .disabled(playerViewModel.currentRecord == nil)

        Button(isSidebarVisible ? "隐藏书签管理器" : "显示书签管理器") {
            onToggleSidebar()
        }

        Divider()

        Button("快退 5 秒") {
            playerViewModel.skip(by: -5)
        }
        Button("快进 5 秒") {
            playerViewModel.skip(by: 5)
        }

        Divider()

        Button("降低速度到 \(String(format: "%.1fx", max(0.1, playerViewModel.playbackRate - 0.1)))") {
            playerViewModel.changePlaybackRate(by: -0.1)
        }
        Button("提高速度到 \(String(format: "%.1fx", min(3.0, playerViewModel.playbackRate + 0.1)))") {
            playerViewModel.changePlaybackRate(by: 0.1)
        }
        Button("恢复 1.0x") {
            playerViewModel.resetPlaybackRate()
        }

        Divider()

        Button(playerViewModel.isMuted ? "取消静音" : "静音") {
            playerViewModel.toggleMute()
        }
        Button("全屏") {
            NSApp.keyWindow?.toggleFullScreen(nil)
        }
    }
}

private struct MouseTrackingView: NSViewRepresentable {
    let onMouseMoved: () -> Void
    let onMouseDown: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onMouseMoved = onMouseMoved
        view.onMouseDown = onMouseDown
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onMouseMoved = onMouseMoved
        nsView.onMouseDown = onMouseDown
        nsView.onDoubleClick = onDoubleClick
    }
}

private final class TrackingNSView: NSView {
    var onMouseMoved: (() -> Void)?
    var onMouseDown: (() -> Void)?
    var onDoubleClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
                owner: self
            )
        )
    }

    override func mouseMoved(with event: NSEvent) {
        onMouseMoved?()
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        if event.clickCount == 2 {
            onDoubleClick?()
        }
        super.mouseDown(with: event)
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else {
            return
        }
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.fullSizeContentView)
        window.minSize = NSSize(width: 760, height: 460)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .black
        window.appearance = NSAppearance(named: .darkAqua)
        window.isMovableByWindowBackground = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.black.cgColor
    }
}

private struct KeyCommandView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyCommandNSView {
        let view = KeyCommandNSView()
        view.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCommandNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            if nsView.window?.firstResponder == nil {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class KeyCommandNSView: NSView {
    private static weak var current: KeyCommandNSView?
    var onKeyDown: ((NSEvent) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        Self.current = self
    }

    static func focusCurrent() {
        current?.window?.makeFirstResponder(current)
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
}

private struct SidebarResizeHandle: View {
    @Binding var width: CGFloat

    var body: some View {
        SidebarResizeHandleView(width: $width)
            .frame(width: 12)
    }
}

private struct SidebarResizeHandleView: NSViewRepresentable {
    @Binding var width: CGFloat

    func makeNSView(context: Context) -> SidebarResizeNSView {
        let view = SidebarResizeNSView()
        view.width = width
        view.onWidthChange = { width = $0 }
        return view
    }

    func updateNSView(_ nsView: SidebarResizeNSView, context: Context) {
        nsView.width = width
        nsView.onWidthChange = { width = $0 }
    }
}

private final class SidebarResizeNSView: NSView {
    var width: CGFloat = 320
    var onWidthChange: ((CGFloat) -> Void)?
    private var dragInitialWidth: CGFloat = 320
    private lazy var panRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handlePan))

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.withAlphaComponent(0.18).setFill()
        NSRect(
            x: bounds.midX - 0.5,
            y: bounds.midY - 16,
            width: 1,
            height: 32
        ).fill()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.001).cgColor
        addGestureRecognizer(panRecognizer)
    }

    @objc
    private func handlePan(_ recognizer: NSPanGestureRecognizer) {
        guard let contentView = window?.contentView else {
            return
        }

        switch recognizer.state {
        case .began:
            dragInitialWidth = width
        case .changed:
            let translation = recognizer.translation(in: contentView)
            let newWidth = min(SidebarLayout.maxWidth, max(SidebarLayout.minWidth, dragInitialWidth - translation.x))
            guard abs(newWidth - width) > 0.1 else {
                return
            }
            width = newWidth
            onWidthChange?(newWidth)
        default:
            break
        }
    }
}

private final class DroppedURLAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var indexedURLs: [Int: URL] = [:]

    func append(_ url: URL, at index: Int) {
        lock.lock()
        indexedURLs[index] = url
        lock.unlock()
    }

    func urlsInOriginalOrder() -> [URL] {
        lock.lock()
        let urls = indexedURLs.keys.sorted().compactMap { indexedURLs[$0] }
        lock.unlock()
        return urls
    }
}

private struct FileDropBridge: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> FileDropNSView {
        let view = FileDropNSView()
        view.onTargetChanged = { isTargeted = $0 }
        view.onDrop = onDrop
        return view
    }

    func updateNSView(_ nsView: FileDropNSView, context: Context) {
        nsView.onTargetChanged = { isTargeted = $0 }
        nsView.onDrop = onDrop
    }
}

private final class FileDropNSView: NSView {
    var onTargetChanged: ((Bool) -> Void)?
    var onDrop: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .URL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL])
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard fileURLs(from: sender).isEmpty == false else {
            return []
        }
        onTargetChanged?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        fileURLs(from: sender).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onTargetChanged?(false)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender)
        onTargetChanged?(false)
        guard !urls.isEmpty else {
            return false
        }
        onDrop?(urls)
        return true
    }

    override func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        onTargetChanged?(false)
    }

    private func fileURLs(from sender: any NSDraggingInfo) -> [URL] {
        let pasteboard = sender.draggingPasteboard
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) ?? []
        return objects.compactMap { object in
            if let url = object as? URL {
                return url
            }
            if let url = object as? NSURL {
                return url as URL
            }
            return nil
        }
    }
}

private func droppedURL(from item: (any NSSecureCoding)?) -> URL? {
    if let url = item as? URL {
        return url
    }

    if let url = item as? NSURL {
        return url as URL
    }

    if let string = item as? String {
        return URL(string: string)
    }

    if let string = item as? NSString {
        return URL(string: string as String)
    }

    let data = item as? Data
    if let dataURL = data.flatMap({ URL(dataRepresentation: $0, relativeTo: nil) }) {
        return dataURL
    }

    if let data, let string = String(data: data, encoding: .utf8) {
        return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return nil
}
