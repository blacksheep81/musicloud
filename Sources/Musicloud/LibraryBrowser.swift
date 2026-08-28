import SwiftUI
import MusicloudCore

struct AlbumGridView: View {
    @ObservedObject var model: PlayerModel
    let albums: [Album]
    let select: (Album.ID) -> Void
    var body: some View {
        if albums.isEmpty {
            ContentUnavailableView.search
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 24)], alignment: .leading, spacing: 24) {
                    ForEach(albums) { album in
                        Button { select(album.id) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                AlbumArtwork(url: album.tracks.first?.url)
                                Text(album.title).font(.headline).lineLimit(1)
                                Text(album.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                Text("\(album.tracks.count) tracks").font(.caption).foregroundStyle(.secondary)
                            }.contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusable()
                        .onKeyPress(.return) { select(album.id); return .handled }
                        .contextMenu {
                            Button("Play Album", systemImage: "play.fill") {
                                if let first = album.tracks.first { model.play(first, in: album.tracks) }
                            }
                            Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") { model.enqueue(album.tracks, next: true) }
                            Button("Add to Queue", systemImage: "text.badge.plus") { model.enqueue(album.tracks) }
                        }
                    }
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
    }
}

struct AlbumDetailView: View {
    @ObservedObject var model: PlayerModel
    let album: Album
    let search: String
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 20) {
                AlbumArtwork(url: album.tracks.first?.url).frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 8) {
                    Text(album.title).font(.title2.weight(.semibold)).lineLimit(2)
                    Text(album.artist).foregroundStyle(.secondary).lineLimit(1)
                    Text("\(album.tracks.count) tracks").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Play", systemImage: "play.fill") {
                            if let first = album.tracks.first { model.play(first, in: album.tracks) }
                        }.buttonStyle(.borderedProminent)
                        Button { model.enqueue(album.tracks) } label: { Image(systemName: "text.badge.plus") }
                            .help("Add album to queue").accessibilityLabel("Add album to queue")
                            .keyboardShortcut("e", modifiers: [.command, .shift])
                    }
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 24).padding(.bottom, 24)
            SongTable(model: model, tracks: album.tracks.filter { $0.matches(search) })
        }
    }
}

struct SongTable: View {
    @ObservedObject var model: PlayerModel
    let tracks: [Track]
    @State private var selection: Set<URL> = []
    var body: some View {
        if tracks.isEmpty {
            ContentUnavailableView.search
        } else {
            Table(tracks, selection: $selection) {
                TableColumn("Title") { track in
                    HStack(spacing: 8) {
                        Image(systemName: model.current?.id == track.id ? "speaker.wave.2.fill" : "music.note")
                            .foregroundStyle(model.current?.id == track.id ? .teal : .secondary).frame(width: 20)
                        Text(track.title).lineLimit(1)
                    }
                }
                TableColumn("Artist") { Text($0.artist).lineLimit(1) }
                TableColumn("Format", value: \.format).width(60)
            }
            .contextMenu(forSelectionType: URL.self) { ids in
                Button("Play", systemImage: "play.fill") {
                    if let track = tracks.first(where: { ids.contains($0.id) }) { model.play(track, in: tracks) }
                }.disabled(ids.isEmpty)
                Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                    model.enqueue(tracks.filter { ids.contains($0.id) }, next: true)
                }.disabled(ids.isEmpty)
                Button("Add to Queue", systemImage: "text.badge.plus") {
                    model.enqueue(tracks.filter { ids.contains($0.id) })
                }.disabled(ids.isEmpty)
                Divider()
                Button("Remove from Library", systemImage: "minus.circle", role: .destructive) { model.remove(ids) }
                    .disabled(ids.isEmpty)
            } primaryAction: { ids in
                if let track = tracks.first(where: { ids.contains($0.id) }) { model.play(track, in: tracks) }
            }
        }
    }
}

struct QueueView: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Queue").font(.headline)
                Spacer()
                Button { model.queue.clearUpcoming() } label: { Image(systemName: "text.badge.minus") }
                    .help("Clear upcoming tracks").accessibilityLabel("Clear upcoming tracks")
                    .disabled(model.queue.upcoming.isEmpty)
            }.padding(.horizontal, 16).padding(.top, 20)
            if let current = model.current {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOW PLAYING").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        AlbumArtwork(url: current.url).frame(width: 40, height: 40)
                        VStack(alignment: .leading) {
                            Text(current.title).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text(current.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }.padding(.horizontal, 16)
            }
            Text("UP NEXT: \(model.queue.upcoming.count)")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16)
            if model.queue.upcoming.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list").font(.system(size: 28))
                    Text("Queue Empty").font(.subheadline)
                }
                .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 32)
            } else {
                List {
                    ForEach(Array(model.queue.upcoming.enumerated()), id: \.element.id) { index, entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text("\(index + 1)").font(.caption).foregroundStyle(.secondary).frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.track.title).lineLimit(1)
                                    Text(entry.track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            HStack {
                                Button { model.playQueued(entry.id) } label: { Image(systemName: "play.fill") }
                                    .help("Play now").accessibilityLabel("Play now")
                                Spacer()
                                Button { model.queue.move(entry.id, by: -1) } label: { Image(systemName: "arrow.up") }
                                    .disabled(index == 0).help("Move up").accessibilityLabel("Move up")
                                Button { model.queue.move(entry.id, by: 1) } label: { Image(systemName: "arrow.down") }
                                    .disabled(index == model.queue.upcoming.count - 1).help("Move down").accessibilityLabel("Move down")
                                Button { model.queue.remove(entry.id) } label: { Image(systemName: "xmark") }
                                    .help("Remove from queue").accessibilityLabel("Remove from queue")
                            }.buttonStyle(.borderless).font(.caption)
                        }.padding(.vertical, 6)
                    }
                }.listStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}
