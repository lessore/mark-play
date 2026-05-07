import SwiftUI

struct PlayerControlsView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    let isOverlay: Bool

    init(isOverlay: Bool = false) {
        self.isOverlay = isOverlay
    }

    var body: some View {
        VStack(spacing: 10) {
            Slider(
                value: progressBinding,
                in: 0...1
            )
            .disabled(playerViewModel.duration <= 0)

            ViewThatFits(in: .horizontal) {
                fullControls
                compactControls
            }
            .buttonStyle(.bordered)
            .controlSize(isOverlay ? .large : .regular)
        }
        .foregroundStyle(isOverlay ? Color.white : Color.primary)
        .tint(isOverlay ? .white : .accentColor)
    }

    private var fullControls: some View {
        HStack(spacing: 12) {
            transportControls

            timeLabel

            Spacer(minLength: 12)

            speedControls

            fullscreenButton

            volumeControls(showSlider: true)
        }
    }

    private var compactControls: some View {
        HStack(spacing: 8) {
            transportControls

            timeLabel
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 118, alignment: .leading)

            Spacer(minLength: 8)

            Text(String(format: "%.1fx", playerViewModel.playbackRate))
                .font(.system(.body, design: .monospaced))
                .frame(width: 48)

            Button {
                playerViewModel.changePlaybackRate(by: 0.1)
            } label: {
                Image(systemName: "plus")
            }
            .help("提高播放速度 0.1x")
            .disabled(playerViewModel.currentURL == nil)

            fullscreenButton

            volumeControls(showSlider: false)
        }
    }

    private var transportControls: some View {
        HStack(spacing: 8) {
                Button {
                    playerViewModel.skip(by: -5)
                } label: {
                    Image(systemName: "gobackward.5")
                }
                .help("快退 5 秒")
                .disabled(playerViewModel.currentURL == nil)

                Button {
                    playerViewModel.togglePlayback()
                } label: {
                    Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 18)
                }
                .keyboardShortcut(.space, modifiers: [])
                .help("播放 / 暂停")
                .disabled(playerViewModel.currentURL == nil)

                Button {
                    playerViewModel.skip(by: 5)
                } label: {
                    Image(systemName: "goforward.5")
                }
                .help("快进 5 秒")
                .disabled(playerViewModel.currentURL == nil)
        }
    }

    private var timeLabel: some View {
        Text("\(TimeFormatter.hms(playerViewModel.currentTime)) / \(TimeFormatter.hms(playerViewModel.duration))")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(isOverlay ? Color.white.opacity(0.82) : .secondary)
            .frame(minWidth: 160, alignment: .leading)
    }

    private var speedControls: some View {
        HStack(spacing: 8) {
            Button {
                playerViewModel.changePlaybackRate(by: -0.1)
            } label: {
                Image(systemName: "minus")
            }
            .help("降低播放速度 0.1x")

            Text(String(format: "%.1fx", playerViewModel.playbackRate))
                .font(.system(.body, design: .monospaced))
                .frame(width: 48)

            Button {
                playerViewModel.changePlaybackRate(by: 0.1)
            } label: {
                Image(systemName: "plus")
            }
            .help("提高播放速度 0.1x")

            Button {
                playerViewModel.resetPlaybackRate()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("恢复 1.0x")
        }
        .disabled(playerViewModel.currentURL == nil)
    }

    private var fullscreenButton: some View {
        Button {
            NSApp.keyWindow?.toggleFullScreen(nil)
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
        }
        .help("全屏")
    }

    private func volumeControls(showSlider: Bool) -> some View {
        HStack(spacing: 8) {
                Button {
                    playerViewModel.toggleMute()
                } label: {
                    Image(systemName: playerViewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .help("静音")
                .disabled(playerViewModel.currentURL == nil)

            if showSlider {
                    Slider(
                        value: volumeBinding,
                        in: 0...1
                    )
                    .frame(width: 110)
                    .disabled(playerViewModel.currentURL == nil)
            }
        }
    }

    private var progressBinding: Binding<Double> {
        Binding(
            get: {
                guard playerViewModel.duration > 0 else {
                    return 0
                }
                return playerViewModel.currentTime / playerViewModel.duration
            },
            set: { playerViewModel.setProgress($0) }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(playerViewModel.volume) },
            set: {
                playerViewModel.volume = Float($0)
                playerViewModel.player.volume = Float($0)
            }
        )
    }
}
