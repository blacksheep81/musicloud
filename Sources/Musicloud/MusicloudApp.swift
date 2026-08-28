import AppKit
import SwiftUI
import MusicloudCore

@main
struct MusicloudApp: App {
    @StateObject private var model = PlayerModel()
    var body: some Scene {
        WindowGroup("musicloud") {
            LibraryView(model: model)
                .frame(minWidth: 850, minHeight: 560)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Music...") { model.importFiles() }
                    .keyboardShortcut("o").disabled(model.isImporting)
                Button("Play / Pause") { model.togglePlayback() }
                    .keyboardShortcut("p").disabled(model.tracks.isEmpty)
            }
        }
    }
}

enum MusicTheme {
    static let canvas = Color(red: 0.075, green: 0.078, blue: 0.085)
    static let sidebar = Color(red: 0.10, green: 0.105, blue: 0.115)
    static let accent = Color(red: 0.72, green: 0.87, blue: 0.77)
}

private enum LibrarySection: String, CaseIterable {
    case albums = "Albums"
    case songs = "Songs"
    var icon: String { self == .albums ? "square.grid.2x2" : "music.note.list" }
}

struct LibraryView: View {
    @ObservedObject var model: PlayerModel
    @State private var search = ""
    @State private var section: LibrarySection = .albums
    @State private var albumID: Album.ID?
    @State private var showQueue = false
    @State private var showOneDrive = false
    @State private var showStage = false
    private var albums: [Album] { model.albums }
    private var album: Album? { albums.first { $0.id == albumID } }
    private var resultCount: Int {
        section == .albums
            ? albums.filter { search.isEmpty || $0.tracks.contains { $0.matches(search) } }.count
            : model.tracks.filter { $0.matches(search) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if !showStage { sidebar }
                VStack(spacing: 0) {
                    header
                    if showStage {
                        ListeningView(model: model)
                    } else {
                        library
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                if showQueue {
                    Divider()
                    QueueView(model: model)
                        .frame(width: 250).background(MusicTheme.sidebar)
                }
            }
            Divider().overlay(.white.opacity(0.05))
            TransportView(model: model, showStage: $showStage, showQueue: $showQueue)
        }
        .background(MusicTheme.canvas)
        .preferredColorScheme(.dark)
        .tint(MusicTheme.accent)
        .sheet(isPresented: $showOneDrive) { OneDriveView(cloud: model.oneDrive, player: model) }
        .alert("musicloud", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 32) {
            HStack(spacing: 10) {
                Image(systemName: "cloud.fill").foregroundStyle(MusicTheme.accent)
                Text("musicloud").font(.system(size: 22, weight: .semibold, design: .rounded))
            }.padding(.top, 32)
            VStack(alignment: .leading, spacing: 8) {
                Text("LIBRARY").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(10)
                ForEach(LibrarySection.allCases, id: \.self) { item in
                    Button {
                        section = item
                        albumID = nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon).frame(width: 18)
                            Text(item.rawValue).fontWeight(.medium)
                            Spacer()
                            Text("\(item == .albums ? albums.count : model.tracks.count)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(section == item ? .white.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(section == item ? MusicTheme.accent : .white.opacity(0.65))
                    }.buttonStyle(.plain)
                        .keyboardShortcut(KeyEquivalent(item == .albums ? "1" : "2"))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("SOURCES").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(10)
                Button { showOneDrive = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cloud").foregroundStyle(.cyan).frame(width: 18)
                        Text("OneDrive")
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.secondary)
                    }.padding(12)
                }.buttonStyle(.plain).keyboardShortcut("d", modifiers: [.command, .shift])
            }
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "internaldrive").foregroundStyle(MusicTheme.accent)
                Text("\(model.tracks.filter { $0.cloud == nil }.count) local tracks")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
        .frame(width: 188).background(MusicTheme.sidebar)
    }

    private var header: some View {
        HStack(spacing: 16) {
            if showStage {
                Button { showStage = false } label: { Image(systemName: "chevron.down") }
                    .buttonStyle(PlayerIconStyle()).help("Back to library").accessibilityLabel("Back to library")
                Text("NOW PLAYING").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            } else {
                if album != nil {
                    Button { albumID = nil } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(PlayerIconStyle()).help("Back to albums").accessibilityLabel("Back to albums")
                }
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search your music", text: $search).textFieldStyle(.plain)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).help("Clear search").accessibilityLabel("Clear search")
                    }
                }.padding(10).frame(maxWidth: 310)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            }
            Spacer(minLength: 0)
            Button { model.importFiles() } label: { Image(systemName: "folder.badge.plus") }
                .buttonStyle(PlayerIconStyle()).help("Import music").accessibilityLabel("Import music")
                .disabled(model.isImporting)
        }.padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 20)
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 0) {
            if album == nil {
                HStack(alignment: .firstTextBaseline) {
                    Text(section.rawValue).font(.system(size: 30, weight: .semibold))
                    Spacer()
                    Text("\(resultCount) \(section == .albums ? "albums" : "tracks")")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.horizontal, 28).padding(.bottom, 24)
            }
            ImportStatusView(model: model)
            if model.tracks.isEmpty {
                ContentUnavailableView {
                    Label("Your Library", systemImage: "opticaldisc")
                } actions: {
                    Button("Import Music", systemImage: "folder.badge.plus") { model.importFiles() }
                        .disabled(model.isImporting)
                }
            } else if section == .songs {
                SongTable(model: model, tracks: model.tracks.filter { $0.matches(search) })
            } else if let album {
                AlbumDetailView(model: model, album: album, search: search)
            } else {
                AlbumGridView(model: model, albums: albums.filter {
                    search.isEmpty || $0.tracks.contains { $0.matches(search) }
                }) { albumID = $0 }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct ImportStatusView: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        if model.isImporting {
            HStack(spacing: 12) {
                if let progress = model.importProgress {
                    ProgressView(value: Double(progress.completed), total: Double(max(1, progress.total))).frame(width: 120)
                    Text("\(progress.completed) / \(progress.total)").monospacedDigit()
                } else {
                    ProgressView().controlSize(.small)
                    Text("Scanning folders...")
                }
                Spacer()
                Button { model.cancelImport() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).help("Cancel import").accessibilityLabel("Cancel import")
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 28).padding(.bottom, 12)
        } else if let summary = model.importSummary {
            Text(summary).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 28).padding(.bottom, 12)
        }
    }
}

struct PlayerIconStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
            .background(.white.opacity(configuration.isPressed ? 0.14 : 0.04), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct TransportView: View {
    @ObservedObject var model: PlayerModel
    @Binding var showStage: Bool
    @Binding var showQueue: Bool
    var body: some View {
        HStack(spacing: 24) {
            Button { showStage.toggle() } label: {
                HStack(spacing: 12) {
                    AlbumArtwork(url: model.current?.url).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(model.current?.title ?? "Nothing playing").font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(model.current?.artist ?? "musicloud").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.frame(width: 205, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help("Open now playing").accessibilityLabel("Open now playing")
            VStack(spacing: 6) {
                HStack(spacing: 22) {
                    Button { model.previous() } label: { Image(systemName: "backward.end.fill") }
                        .help("Previous").accessibilityLabel("Previous").disabled(model.current == nil)
                    Button { model.togglePlayback() } label: {
                        ZStack {
                            Circle().fill(MusicTheme.accent)
                            if model.isPreparing { ProgressView().controlSize(.small).tint(.black) }
                            else {
                                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundStyle(.black).font(.system(size: 15, weight: .semibold))
                            }
                        }.frame(width: 34, height: 34)
                    }.help(model.isPlaying ? "Pause" : "Play").accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                        .disabled(model.tracks.isEmpty || model.isPreparing)
                    Button { model.next() } label: { Image(systemName: "forward.end.fill") }
                        .help("Next").accessibilityLabel("Next").disabled(model.queue.upcoming.isEmpty)
                }.buttonStyle(.plain)
                HStack(spacing: 8) {
                    Text(timestamp(model.elapsed)).frame(width: 34)
                    Slider(value: Binding(get: { min(model.elapsed, max(model.duration, 1)) }, set: { model.seek($0) }), in: 0...max(model.duration, 1))
                        .controlSize(.mini).disabled(model.duration <= 0).accessibilityLabel("Playback position")
                    Text(timestamp(model.duration)).frame(width: 34)
                }.font(.system(size: 10)).monospacedDigit().foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2").font(.caption).foregroundStyle(.secondary)
                Slider(value: $model.volume, in: 0...1).controlSize(.mini).frame(width: 64).accessibilityLabel("Volume")
                Button { showQueue.toggle() } label: { Image(systemName: "list.bullet").foregroundStyle(showQueue ? MusicTheme.accent : .secondary) }
                    .help("Playback queue").accessibilityLabel("Playback queue")
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button { showStage.toggle() } label: { Image(systemName: showStage ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") }
                    .help("Toggle now playing").accessibilityLabel("Toggle now playing")
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            }.buttonStyle(PlayerIconStyle())
        }.padding(.horizontal, 24).padding(.vertical, 14).background(MusicTheme.sidebar)
    }
    private func timestamp(_ seconds: Double) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct ListeningView: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        GeometryReader { geometry in
            let size = min(320.0, max(150.0, geometry.size.height - 160), geometry.size.width * 0.34)
            HStack(spacing: 48) {
                VStack(alignment: .leading, spacing: 20) {
                    AlbumArtwork(url: model.current?.url).frame(width: size, height: size)
                        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.current?.title ?? "Nothing playing")
                            .font(.system(size: 23, weight: .semibold)).lineLimit(2)
                        Text(model.current?.artist ?? "musicloud").font(.system(size: 15)).foregroundStyle(.secondary).lineLimit(1)
                        if let track = model.current {
                            Text("\(track.format)  /  \(track.cloud == nil ? "LOCAL" : "ONEDRIVE")")
                                .font(.system(size: 10, weight: .medium)).foregroundStyle(MusicTheme.accent)
                        }
                    }
                }.frame(width: size, alignment: .leading)
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "text.quote").font(.system(size: 26, weight: .light)).foregroundStyle(MusicTheme.accent)
                    Text("No lyrics available")
                        .font(.system(size: 32, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                    if let current = model.current {
                        Text(current.album).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 40)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
