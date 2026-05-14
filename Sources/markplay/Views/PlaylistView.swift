import SwiftData
import SwiftUI

struct PlaylistView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var playlistViewModel: PlaylistViewModel
    @State private var selectedItemID: PlaylistItem.ID?

    var body: some View {
        VStack(spacing: 0) {
            if playlistViewModel.items.isEmpty {
                PlaceholderView(
                    title: "播放列表为空",
                    message: "拖入 MP3 或从菜单添加",
                    systemImage: "music.note.list"
                )
            } else {
                playlistList
                footer
            }
        }
    }

    private var playlistList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(playlistViewModel.items.enumerated()), id: \.element.id) { index, item in
                        PlaylistRowView(
                            index: index,
                            item: item,
                            isSelected: item.id == selectedItemID,
                            isCurrent: item.id == playlistViewModel.currentItemID
                        )
                        .id(item.id)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .simultaneousGesture(TapGesture(count: 1).onEnded {
                            selectedItemID = item.id
                        })
                        .highPriorityGesture(TapGesture(count: 2).onEnded {
                            selectedItemID = item.id
                            play(item)
                        })
                        .contextMenu {
                            Button("播放") {
                                selectedItemID = item.id
                                play(item)
                            }

                            Button("从列表移除") {
                                remove(item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .background(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedItemID = nil
            }
            .onChange(of: playlistViewModel.currentItemID) { _, id in
                guard let id else {
                    return
                }
                selectedItemID = id
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onDeleteCommand {
                deleteSelectedItem()
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("\(playlistViewModel.items.count) 首")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.58))

            Spacer()

            Button {
                playSelectedOrFirst()
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.white.opacity(0.84))
            .help("播放选中项")
            .disabled(!playlistViewModel.hasItems)

            Button {
                playlistViewModel.playNext(context: modelContext, playerViewModel: playerViewModel)
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.white.opacity(0.84))
            .help("播放下一首")
            .disabled(!playlistViewModel.hasItems)

            Button {
                playlistViewModel.clear()
                selectedItemID = nil
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.white.opacity(0.72))
            .help("清空播放列表")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.18))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func play(_ item: PlaylistItem) {
        playlistViewModel.play(
            itemID: item.id,
            context: modelContext,
            playerViewModel: playerViewModel
        )
    }

    private func remove(_ item: PlaylistItem) {
        playlistViewModel.remove(itemID: item.id)
        if selectedItemID == item.id {
            selectedItemID = nil
        }
    }

    private func deleteSelectedItem() {
        guard let selectedItemID else {
            return
        }
        playlistViewModel.remove(itemID: selectedItemID)
        self.selectedItemID = nil
    }

    private func playSelectedOrFirst() {
        if let selectedItemID, let item = playlistViewModel.items.first(where: { $0.id == selectedItemID }) {
            play(item)
            return
        }

        guard let firstItem = playlistViewModel.items.first else {
            return
        }
        selectedItemID = firstItem.id
        play(firstItem)
    }
}

private struct PlaylistRowView: View {
    let index: Int
    let item: PlaylistItem
    let isSelected: Bool
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                .foregroundStyle(iconColor)
                .frame(width: 17)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)

                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(rowStroke, lineWidth: 1)
        )
    }

    private var rowBackground: Color {
        if isCurrent {
            return Color.accentColor.opacity(0.22)
        }

        if isSelected {
            return Color.accentColor.opacity(0.14)
        }

        return Color.clear
    }

    private var rowStroke: Color {
        if isCurrent {
            return Color.accentColor.opacity(0.34)
        }

        if isSelected {
            return Color.accentColor.opacity(0.22)
        }

        return Color.clear
    }

    private var iconColor: Color {
        if isCurrent || isSelected {
            return .accentColor
        }
        return Color.white.opacity(0.54)
    }

    private var titleColor: Color {
        Color.white.opacity(isCurrent || isSelected ? 0.96 : 0.90)
    }

    private var detailColor: Color {
        if isCurrent || isSelected {
            return Color.white.opacity(0.76)
        }
        return Color.white.opacity(0.46)
    }
}
