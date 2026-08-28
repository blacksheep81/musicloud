import AppKit
import MusicloudAudio
import SwiftUI

@MainActor
final class ArtworkStore {
    static let shared = ArtworkStore()
    private let cache = NSCache<NSURL, NSImage>()

    init() { cache.countLimit = 100 }

    func image(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let worker = Task.detached(priority: .utility) { await ArtworkLoader.load(url) }
        let bitmap = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
        guard !Task.isCancelled, let bitmap else { return nil }
        let image = NSImage(cgImage: bitmap, size: NSSize(width: bitmap.width, height: bitmap.height))
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

}

struct AlbumArtwork: View {
    let url: URL?
    @State private var image: NSImage?

    var body: some View {
        Rectangle().fill(.quaternary).aspectRatio(1, contentMode: .fit).overlay {
          GeometryReader { geometry in
            ZStack {
                Rectangle().fill(.quaternary)
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "opticaldisc")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task(id: url) {
            image = nil
            guard let url else { return }
            let loaded = await ArtworkStore.shared.image(for: url)
            if !Task.isCancelled { image = loaded }
        }
        .accessibilityLabel("Album artwork")
    }
}
