import AVFoundation
import Foundation
import MusicloudCore

public struct ImportProgress: Sendable {
    public let completed: Int
    public let total: Int
}

public struct ImportResult: Sendable {
    public let tracks: [Track]
    public let issues: [String]
}

public enum LocalImporter {
    public static func run(
        roots: [URL], excluding: Set<URL>,
        progress: @escaping @Sendable (ImportProgress) async -> Void
    ) async throws -> ImportResult {
        try Task.checkCancellation()
        let worker = Task.detached(priority: .utility) {
            let scan = try LocalScanner.scan(roots, excluding: excluding)
            var tracks: [Track] = []
            var issues = scan.issues
            await progress(ImportProgress(completed: 0, total: scan.urls.count))
            for (index, url) in scan.urls.enumerated() {
                try Task.checkCancellation()
                do {
                    let asset = AVURLAsset(url: url)
                    guard try await asset.load(.isPlayable) else {
                        issues.append("Unsupported or damaged audio: \(url.lastPathComponent)")
                        await progress(ImportProgress(completed: index + 1, total: scan.urls.count))
                        continue
                    }
                    var track = Track(url: url)
                    if let metadata = try? await asset.load(.metadata) {
                        for entry in metadata {
                            guard [.commonKeyTitle, .commonKeyArtist, .commonKeyAlbumName].contains(entry.commonKey),
                                  let value = try? await entry.load(.stringValue), !value.isEmpty else { continue }
                            switch entry.commonKey {
                            case .commonKeyTitle: track.title = value
                            case .commonKeyArtist: track.artist = value
                            case .commonKeyAlbumName: track.album = value
                            default: break
                            }
                        }
                    }
                    tracks.append(track)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    issues.append("\(url.lastPathComponent): \(error.localizedDescription)")
                }
                await progress(ImportProgress(completed: index + 1, total: scan.urls.count))
            }
            try Task.checkCancellation()
            return ImportResult(tracks: tracks, issues: issues)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }
}
