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
        .defaultSize(width: 1100, height: 740)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Music...") { model.importFiles() }
                    .keyboardShortcut("o").disabled(model.isImporting)
            }
        }
    }
}

private enum LibrarySection: String, CaseIterable {
    case albums = "Albums"
    case songs = "All Songs"
    var icon: String { self == .albums ? "square.grid.2x2" : "music.note.list" }
}

struct LibraryView: View {
    @ObservedObject var model: PlayerModel
    @State private var search = ""
    @State private var section: LibrarySection = .albums
    @State private var albumID: Album.ID?
    @State private var showQueue = false
    @State private var showOneDrive = false
    private var albums: [Album] { model.albums }
    private var album: Album? { albums.first { $0.id == albumID } }

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("musicloud", systemImage: "cloud")
                        .font(.title2.weight(.semibold)).padding(.top, 12)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LIBRARY").font(.caption).foregroundStyle(.secondary)
                        ForEach(LibrarySection.allCases, id: \.self) { item in
                            Button {
                                section = item
                                albumID = nil
                            } label: {
                                Label(item.rawValue, systemImage: item.icon)
                                    .font(.body.weight(.medium))
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                                    .background(section == item ? Color.teal.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(KeyEquivalent(item == .albums ? "1" : "2"))
                            .foregroundStyle(section == item ? .teal : .primary)
                        }
                        Text("\(albums.count) albums / \(model.tracks.count) tracks")
                            .font(.caption).foregroundStyle(.secondary).padding(.leading, 8)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SOURCES").font(.caption).foregroundStyle(.secondary)
                        Button { showOneDrive = true } label: {
                            Label("OneDrive", systemImage: "cloud")
                                .frame(maxWidth: .infinity, alignment: .leading).padding(8)
                        }.buttonStyle(.plain).keyboardShortcut("d", modifiers: [.command, .shift])
                    }
                    Spacer()
                    if let current = model.current {
                        AlbumArtwork(url: current.url).frame(width: 156, height: 156)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(current.title).font(.headline).lineLimit(2)
                            Text(current.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            } detail: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        if album != nil {
                            Button { albumID = nil } label: { Image(systemName: "chevron.left") }
                                .help("Back to albums").accessibilityLabel("Back to albums")
                        }
                        Text(section.rawValue).font(.title2.weight(.semibold))
                        Spacer()
                        Button { model.importFiles() } label: { Image(systemName: "folder.badge.plus") }
                            .help("Import music").accessibilityLabel("Import music").disabled(model.isImporting)
                        Button { showQueue.toggle() } label: { Image(systemName: "list.bullet") }
                            .help("Playback queue").accessibilityLabel("Playback queue")
                            .keyboardShortcut("l", modifiers: [.command, .shift])
                    }.padding(24)
                    ImportStatusView(model: model)
                    if model.tracks.isEmpty {
                        ContentUnavailableView {
                            Label("No Music Yet", systemImage: "music.note")
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
                }
                .searchable(text: $search, prompt: "Search music")
                .inspector(isPresented: $showQueue) {
                    QueueView(model: model).inspectorColumnWidth(min: 240, ideal: 270, max: 320)
                }
            }
            Divider()
            TransportView(model: model).padding(.horizontal, 24).padding(.vertical, 16)
        }
        .tint(.teal)
        .sheet(isPresented: $showOneDrive) { OneDriveView(cloud: model.oneDrive, player: model) }
        .alert("musicloud", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
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
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.bottom, 12)
        } else if let summary = model.importSummary {
            Text(summary).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.bottom, 12)
        }
    }
}

private struct TransportView: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.current?.title ?? "musicloud").font(.headline).lineLimit(1)
                Text(model.current?.artist ?? "No track selected").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.frame(width: 180, alignment: .leading)
            HStack(spacing: 16) {
                Button { model.previous() } label: { Image(systemName: "backward.end.fill") }
                    .help("Previous").disabled(model.current == nil)
                Button { model.togglePlayback() } label: {
                    ZStack {
                        if model.isPreparing { ProgressView().controlSize(.small) }
                        else { Image(systemName: model.isPlaying ? "pause.fill" : "play.fill").font(.title2) }
                    }.frame(width: 32, height: 32)
                }.help(model.isPlaying ? "Pause" : "Play").disabled(model.tracks.isEmpty || model.isPreparing)
                Button { model.next() } label: { Image(systemName: "forward.end.fill") }
                    .help("Next").disabled(model.queue.upcoming.isEmpty)
            }.buttonStyle(.plain)
            HStack(spacing: 8) {
                Text(timestamp(model.elapsed)).monospacedDigit().frame(width: 44)
                Slider(value: Binding(get: { min(model.elapsed, max(model.duration, 1)) }, set: { model.seek($0) }), in: 0...max(model.duration, 1))
                    .disabled(model.duration <= 0).accessibilityLabel("Playback position")
                Text(timestamp(model.duration)).monospacedDigit().frame(width: 44)
            }.font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2")
                Slider(value: $model.volume, in: 0...1).accessibilityLabel("Volume")
            }.frame(width: 110)
        }
    }
    private func timestamp(_ seconds: Double) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
