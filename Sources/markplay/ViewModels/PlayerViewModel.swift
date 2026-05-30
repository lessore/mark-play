import AVFoundation
import Foundation
import SwiftData

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player = AVPlayer()
    @Published var currentURL: URL?
    @Published var currentRecord: VideoRecord?
    @Published var hasVideoTrack = true
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying = false
    @Published var volume: Float = 1
    @Published var isMuted = false
    @Published var playbackRate: Float = 1.0
    @Published var subtitleCues: [SubtitleCue] = []
    @Published var activeSubtitleCue: SubtitleCue?
    @Published var errorMessage: String?

    var onPlaybackEnded: (() -> Void)?

    private var timeObserver: Any?
    private var itemEndObserver: (any NSObjectProtocol)?
    private var subtitleLoadingTask: Task<Void, Never>?

    init() {
        player.volume = volume
        installTimeObserver()
    }

    func openMedia(url: URL, context: ModelContext) {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            errorMessage = "文件无法访问。"
            return
        }

        do {
            let record = try VideoRecordResolver.resolve(url: url, context: context)
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            installItemEndObserver(for: item)
            currentURL = url
            currentRecord = record
            currentTime = 0
            duration = 0
            subtitleLoadingTask?.cancel()
            subtitleCues = []
            activeSubtitleCue = nil
            hasVideoTrack = true
            detectVideoTrack(for: item, url: url)
            loadSubtitlesIfNeeded(for: url)
            applyPlaybackRate()
            errorMessage = nil
        } catch {
            errorMessage = "媒体打开失败：\(error.localizedDescription)"
        }
    }

    func openVideo(url: URL, context: ModelContext) {
        openMedia(url: url, context: context)
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            applyPlaybackRate()
            isPlaying = true
        }
    }

    func seek(to seconds: Double) {
        let bounded = max(0, min(seconds, duration > 0 ? duration : seconds))
        let time = CMTime(seconds: bounded, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = bounded
    }

    func skip(by delta: Double) {
        seek(to: currentTime + delta)
    }

    func setProgress(_ progress: Double) {
        guard duration > 0 else {
            return
        }
        seek(to: duration * progress)
    }

    func changeVolume(by delta: Float) {
        volume = min(1, max(0, volume + delta))
        player.volume = volume
        if volume > 0 {
            isMuted = false
            player.isMuted = false
        }
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    func setPlaybackRate(_ rate: Float) {
        let rounded = (rate * 10).rounded() / 10
        playbackRate = min(3.0, max(0.1, rounded))
        if isPlaying {
            applyPlaybackRate()
        }
    }

    func changePlaybackRate(by delta: Float) {
        setPlaybackRate(playbackRate + delta)
    }

    func resetPlaybackRate() {
        setPlaybackRate(1.0)
    }

    func stopAndClear() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeItemEndObserver()
        currentURL = nil
        currentRecord = nil
        hasVideoTrack = true
        currentTime = 0
        duration = 0
        isPlaying = false
        subtitleCues = []
        activeSubtitleCue = nil
        errorMessage = nil
        subtitleLoadingTask?.cancel()
        subtitleLoadingTask = nil
    }

    private func applyPlaybackRate() {
        player.rate = playbackRate
    }

    private func installTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else {
                return
            }

            Task { @MainActor in
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let item = self.player.currentItem {
                    let itemDuration = item.duration.seconds
                    self.duration = itemDuration.isFinite ? itemDuration : 0
                }
                self.syncActiveSubtitle()
                self.isPlaying = self.player.timeControlStatus == .playing
            }
        }
    }

    private func installItemEndObserver(for item: AVPlayerItem) {
        removeItemEndObserver()
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.onPlaybackEnded?()
            }
        }
    }

    private func removeItemEndObserver() {
        guard let itemEndObserver else {
            return
        }
        NotificationCenter.default.removeObserver(itemEndObserver)
        self.itemEndObserver = nil
    }

    private func syncActiveSubtitle() {
        guard !subtitleCues.isEmpty else {
            activeSubtitleCue = nil
            return
        }

        let cue: SubtitleCue?
        if let index = subtitleCues.lastIndex(where: { $0.startTime <= currentTime }) {
            let candidate = subtitleCues[index]
            cue = candidate.contains(currentTime) ? candidate : nil
        } else {
            cue = nil
        }
        activeSubtitleCue = cue
    }

    private func detectVideoTrack(for item: AVPlayerItem, url: URL) {
        Task { [weak self] in
            let tracks = (try? await item.asset.loadTracks(withMediaType: .video)) ?? []
            await MainActor.run {
                guard let self, self.currentURL == url else {
                    return
                }
                self.hasVideoTrack = !tracks.isEmpty
            }
        }
    }

    private func loadSubtitlesIfNeeded(for url: URL) {
        guard EmbeddedSubtitleParser.canParseFile(at: url) else {
            return
        }

        subtitleLoadingTask = Task { [weak self] in
            let cues = await Task.detached(priority: .utility) {
                (try? EmbeddedSubtitleParser.parse(fromFileAt: url)) ?? []
            }.value

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, self.currentURL == url else {
                    return
                }
                self.subtitleCues = cues
                self.syncActiveSubtitle()
            }
        }
    }
}
