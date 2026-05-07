import AVKit
import SwiftUI

struct VideoPlayerView: NSViewRepresentable {
    @EnvironmentObject private var playerViewModel: PlayerViewModel

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.player = playerViewModel.player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = playerViewModel.player
    }
}
