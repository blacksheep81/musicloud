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
                    .keyboardShortcut("o")
                    .disabled(model.isImporting)
            }
        }
    }
}

struct LibraryView: View {
    @ObservedObject var model: PlayerModel
    @State private var search = ""
    @State private var selection: Set<URL> = []

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("musicloud", systemImage: "cloud")
                        .font(.title2.weight(.semibold))
                        .padding(.top, 12)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LIBRARY").font(.caption).foregroundStyle(.secondary)
                        Label("All Songs", systemImage: "music.note.list")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.teal)
                        Text("\(model.tracks.count) tracks").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let current = model.current {
                        cover.frame(width: 156, height: 156).clipped().clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(current.title).font(.headline).lineLimit(2)
                            Text(current.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
            } detail: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("All Songs").font(.title2.weight(.semibold))
                        Spacer()
                        if model.isImporting { ProgressView().controlSize(.small) }
                        Button { model.importFiles() } label: {
                            Label("Import Music", systemImage: "plus")
                        }
                        .disabled(model.isImporting)
                    }.padding(24)
                    if model.tracks.isEmpty {
                        ContentUnavailableView {
                            Label("No Music Yet", systemImage: "music.note")
                        } actions: {
                            Button("Import Music", systemImage: "folder.badge.plus") { model.importFiles() }
                                .disabled(model.isImporting)
                        }
                    } else {
                        Table(model.tracks.filter { $0.matches(search) }, selection: $selection) {
                            TableColumn("Title") { track in
                                HStack(spacing: 8) {
                                    Image(systemName: model.current?.id == track.id ? "speaker.wave.2.fill" : "music.note")
                                        .foregroundStyle(model.current?.id == track.id ? .teal : .secondary)
                                        .frame(width: 20)
                                    Text(track.title).lineLimit(1)
                                }
                            }
                            TableColumn("Artist", value: \.artist)
                            TableColumn("Album", value: \.album)
                            TableColumn("Format", value: \.format).width(60)
                        }
                        .contextMenu(forSelectionType: URL.self) { ids in
                            Button("Play", systemImage: "play.fill") {
                                if let track = model.tracks.first(where: { ids.contains($0.id) }) { model.play(track) }
                            }.disabled(ids.isEmpty)
                            Button("Remove from Library", systemImage: "minus.circle", role: .destructive) {
                                model.remove(ids)
                            }.disabled(ids.isEmpty)
                        } primaryAction: { ids in
                            if let track = model.tracks.first(where: { ids.contains($0.id) }) { model.play(track) }
                        }
                    }
                }
                .searchable(text: $search, prompt: "Search music")
            }
            Divider()
            transport.padding(.horizontal, 24).padding(.vertical, 16)
        }
        .tint(.teal)
        .alert("musicloud", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    @ViewBuilder private var cover: some View {
        if let image = model.artwork {
            Image(nsImage: image).resizable().scaledToFill()
        } else {
            Rectangle().fill(.quaternary)
                .overlay(Image(systemName: "opticaldisc").font(.system(size: 54, weight: .ultraLight)).foregroundStyle(.secondary))
        }
    }

    private var transport: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.current?.title ?? "musicloud").font(.headline).lineLimit(1)
                Text(model.current?.artist ?? "No track selected").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }.frame(width: 180, alignment: .leading)
            HStack(spacing: 16) {
                Button { model.previous() } label: { Image(systemName: "backward.end.fill") }
                    .help("Previous").disabled(model.current == nil)
                Button { model.togglePlayback() } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2).frame(width: 32, height: 32)
                }.help(model.isPlaying ? "Pause" : "Play").disabled(model.tracks.isEmpty)
                Button { model.next() } label: { Image(systemName: "forward.end.fill") }
                    .help("Next").disabled(model.current == nil || model.current?.id == model.tracks.last?.id)
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
