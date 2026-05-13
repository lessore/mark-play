import AppKit
import SwiftUI

struct SubtitleListView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel

    @State private var rowFrames: [Int: CGRect] = [:]
    @State private var scrollView: NSScrollView?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(playerViewModel.subtitleCues) { cue in
                        SubtitleRowView(
                            cue: cue,
                            isActive: playerViewModel.activeSubtitleCue?.id == cue.id
                        )
                        .id(cue.id)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onTapGesture {
                            playerViewModel.seek(to: cue.startTime)
                        }
                        .background(
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: SubtitleRowFramePreferenceKey.self,
                                    value: [cue.id: geometry.frame(in: .named("subtitle-content"))]
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .coordinateSpace(name: "subtitle-content")
            }
            .background(
                SubtitleScrollViewAccessor { resolvedScrollView in
                    if scrollView !== resolvedScrollView {
                        scrollView = resolvedScrollView
                    }
                }
            )
            .onPreferenceChange(SubtitleRowFramePreferenceKey.self) { rowFrames = $0 }
            .onChange(of: playerViewModel.currentTime) { _, time in
                _ = updateContinuousScroll(for: time, proxy: proxy)
            }
            .onChange(of: playerViewModel.activeSubtitleCue?.id) { _, id in
                guard let id else {
                    return
                }
                guard !updateContinuousScroll(for: playerViewModel.currentTime, proxy: proxy) else {
                    return
                }
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.35))
                }
            }
        }
    }

    private func updateContinuousScroll(for time: Double, proxy: ScrollViewProxy) -> Bool {
        guard let targetMidY = interpolatedTargetMidY(for: time) else {
            return false
        }
        guard let scrollView else {
            return false
        }

        let viewportHeight = scrollView.contentView.bounds.height
        let documentHeight = scrollView.documentView?.bounds.height ?? 0
        guard viewportHeight > 0, documentHeight > viewportHeight else {
            return false
        }

        let desiredOriginY = max(0, min(targetMidY - viewportHeight * 0.36, documentHeight - viewportHeight))
        let currentOriginY = scrollView.contentView.bounds.origin.y
        guard abs(currentOriginY - desiredOriginY) > 0.5 else {
            return true
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.allowsImplicitAnimation = true
            scrollView.contentView.animator().setBoundsOrigin(CGPoint(x: 0, y: desiredOriginY))
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return true
    }

    private func interpolatedTargetMidY(for time: Double) -> CGFloat? {
        let cues = playerViewModel.subtitleCues
        guard !cues.isEmpty else {
            return nil
        }

        guard let currentIndex = cues.lastIndex(where: { $0.startTime <= time }) else {
            return rowFrames[cues[0].id]?.midY
        }

        let currentCue = cues[currentIndex]
        guard let currentFrame = rowFrames[currentCue.id] else {
            return nil
        }

        guard currentIndex + 1 < cues.count else {
            return currentFrame.midY
        }

        let nextCue = cues[currentIndex + 1]
        guard let nextFrame = rowFrames[nextCue.id] else {
            return currentFrame.midY
        }

        let interval = max(0.001, nextCue.startTime - currentCue.startTime)
        let progress = min(max((time - currentCue.startTime) / interval, 0), 1)
        return currentFrame.midY + (nextFrame.midY - currentFrame.midY) * progress
    }
}

private struct SubtitleRowView: View {
    let cue: SubtitleCue
    let isActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(TimeFormatter.hms(cue.startTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isActive ? Color.accentColor : Color.white.opacity(0.64))
                .frame(width: 74, alignment: .leading)

            Text(cue.text)
                .font(.system(size: 15, weight: .regular))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(Color.white.opacity(isActive ? 0.96 : 0.88))
                .textSelection(.enabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var backgroundColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.18)
        }
        return Color.clear
    }

    private var borderColor: Color {
        if isActive {
            return Color.accentColor.opacity(0.28)
        }
        return Color.clear
    }
}

private struct SubtitleRowFramePreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct SubtitleScrollViewAccessor: NSViewRepresentable {
    let onResolve: (NSScrollView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let scrollView = view.enclosingScrollView {
                onResolve(scrollView)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let scrollView = nsView.enclosingScrollView {
                onResolve(scrollView)
            }
        }
    }
}
