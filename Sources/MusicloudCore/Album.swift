import Foundation

public struct Album: Identifiable, Sendable {
    public struct ID: Hashable, Sendable {
        public let title: String
        public let directory: URL
    }

    public let id: ID
    public let tracks: [Track]
    public var title: String { id.title }
    public var artist: String {
        let artists = Set(tracks.map(\.artist))
        return artists.count == 1 ? tracks[0].artist : "Various Artists"
    }

    public static func grouping(_ tracks: [Track]) -> [Album] {
        let groups = Dictionary(grouping: tracks) { track in
            ID(title: track.album, directory: track.url.deletingLastPathComponent())
        }
        return groups.map { id, tracks in
            Album(id: id, tracks: tracks.sorted {
                $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
            })
        }.sorted {
            let order = $0.title.localizedStandardCompare($1.title)
            return order == .orderedSame ? $0.id.directory.path < $1.id.directory.path : order == .orderedAscending
        }
    }
}
