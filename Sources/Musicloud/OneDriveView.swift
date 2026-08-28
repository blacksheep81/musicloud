import SwiftUI
import MusicloudCloud

struct OneDriveView: View {
    @ObservedObject var cloud: OneDriveModel
    @ObservedObject var player: PlayerModel
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("OneDrive", systemImage: "cloud").font(.title2.weight(.semibold))
                Spacer()
                if cloud.isBusy {
                    ProgressView().controlSize(.small)
                    Button { cloud.cancel() } label: { Image(systemName: "xmark.circle") }
                        .help("Cancel request").accessibilityLabel("Cancel request")
                }
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .help("Close").accessibilityLabel("Close")
            }
            if cloud.drive == nil {
                Form {
                    TextField("Application Client ID", text: $cloud.clientID).disabled(cloud.isBusy)
                    Button("Connect OneDrive", systemImage: "person.crop.circle.badge.checkmark") { cloud.connect() }
                        .disabled(!cloud.canConnect || cloud.isBusy)
                }.formStyle(.grouped)
            } else {
                HStack {
                    Button { cloud.back() } label: { Image(systemName: "chevron.left") }
                        .disabled(cloud.path.isEmpty || cloud.isBusy).help("Parent folder")
                    Text(cloud.path.last?.name ?? cloud.drive?.name ?? "OneDrive").font(.headline).lineLimit(1)
                    Spacer()
                    Button { cloud.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(cloud.isBusy).help("Refresh")
                    Button("Disconnect") { player.stopCloudPlayback(); cloud.disconnect() }.disabled(cloud.isBusy)
                }
                Table(cloud.items.filter { $0.isFolder || $0.isAudio }, selection: $selection) {
                    TableColumn("Name") { item in
                        Label(item.name, systemImage: item.isFolder ? "folder" : "music.note").lineLimit(1)
                    }
                    TableColumn("Kind") { Text($0.isFolder ? "Folder" : "Audio") }.width(70)
                }
                .disabled(cloud.isBusy)
                .contextMenu(forSelectionType: String.self) { ids in
                    Button("Open Folder", systemImage: "folder") { open(ids) }
                        .disabled(!cloud.items.contains { ids.contains($0.id) && $0.isFolder })
                    Button("Add to Library", systemImage: "plus") { add(ids) }
                        .disabled(!cloud.items.contains { ids.contains($0.id) && $0.isAudio })
                } primaryAction: { ids in
                    if cloud.items.contains(where: { ids.contains($0.id) && $0.isFolder }) { open(ids) }
                    else { add(ids) }
                }
                HStack {
                    if cloud.nextLink != nil {
                        Button("Load More") { cloud.loadMore() }.disabled(cloud.isBusy)
                    }
                    Spacer()
                    Button("Open Folder", systemImage: "folder") { open(selection) }
                        .disabled(cloud.isBusy || !cloud.items.contains { selection.contains($0.id) && $0.isFolder })
                    Button("Add Selected", systemImage: "plus") { add(selection) }
                        .disabled(cloud.isBusy || !cloud.items.contains { selection.contains($0.id) && $0.isAudio })
                }
            }
            if let error = cloud.error { Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
        }
        .padding(24).frame(width: 650, height: 470)
        .onDisappear { cloud.cancel() }
        .onChange(of: cloud.path.last?.id) { selection = [] }
    }

    private func open(_ ids: Set<String>) {
        if let folder = cloud.items.first(where: { ids.contains($0.id) && $0.isFolder }) { cloud.open(folder) }
    }
    private func add(_ ids: Set<String>) {
        guard let drive = cloud.drive else { return }
        player.addCloudTracks(cloud.items.filter { ids.contains($0.id) && $0.isAudio }.map { $0.track(driveID: drive.id) })
        selection = []
    }
}
