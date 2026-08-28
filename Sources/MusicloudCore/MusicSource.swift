import Foundation

// Stable provider IDs are persisted; expiring cloud download URLs are resolved only at playback.
public struct SourceItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let isFolder: Bool

    public init(id: String, name: String, isFolder: Bool) {
        self.id = id
        self.name = name
        self.isFolder = isFolder
    }
}

public struct SourcePage: Sendable {
    public let items: [SourceItem]
    public let nextCursor: String?

    public init(items: [SourceItem], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

public protocol MusicSource: Sendable {
    func list(folderID: String?, cursor: String?) async throws -> SourcePage
    func playbackURL(for itemID: String) async throws -> URL
}
