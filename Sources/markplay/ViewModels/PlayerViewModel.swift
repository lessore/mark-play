import AVFoundation
import Foundation
import SwiftData

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player = AVPlayer()
    @Published var currentURL: URL?
    @Published var currentRecord: VideoRecord?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying = false
    @Published var volume: Float = 1
    @Published var isMuted = false
    @Published var playbackRate: Float = 1.0
    @Published var errorMessage: String?

    private var timeObserver: Any?

    init() {
        player.volume = volume
        installTimeObserver()
    }

    func openVideo(url: URL, context: ModelContext) {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            errorMessage = "文件无法访问。"
            return
        }

        do {
            let record = try VideoRecordResolver.resolve(url: url, context: context)
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            currentURL = url
            currentRecord = record
            currentTime = 0
            duration = 0
            applyPlaybackRate()
            errorMessage = nil
        } catch {
            errorMessage = "视频打开失败：\(error.localizedDescription)"
        }
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
        currentURL = nil
        currentRecord = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        errorMessage = nil
    }

    private func applyPlaybackRate() {
        player.rate = playbackRate
    }

    private func installTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
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
                self.isPlaying = self.player.timeControlStatus == .playing
            }
        }
    }
}
