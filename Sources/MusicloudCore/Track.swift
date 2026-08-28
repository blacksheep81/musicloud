import Foundation

public struct Track: Identifiable, Codable, Equatable, Sendable {
    public var id: URL { cloud?.identityURL ?? url }
    public let url: URL
    public var title: String
    public var artist: String
    public var album: String
    public var cloud: CloudTrackReference?

    public init(url: URL, title: String? = nil, artist: String = "Unknown Artist", album: String = "Unknown Album") {
        self.url = url.isFileURL ? url.standardizedFileURL.resolvingSymlinksInPath() : url
        self.title = title ?? url.deletingPathExtension().lastPathComponent
        self.artist = artist
        self.album = album
    }

    public var format: String { url.pathExtension.uppercased() }

    public static func supports(_ url: URL) -> Bool {
        ["wav", "flac", "m4a", "mp3", "aif", "aiff", "aac"].contains(url.pathExtension.lowercased())
    }

    public func matches(_ query: String) -> Bool {
        query.isEmpty || [title, artist, album, format].contains {
            $0.localizedStandardContains(query)
        }
    }
}

public enum Library {
    public static func merging(_ existing: [Track], with incoming: [Track]) -> [Track] {
        var seen = Set(existing.map(\.id))
        return existing + incoming.filter { seen.insert($0.id).inserted }
    }
}

public struct CloudTrackReference: Codable, Equatable, Sendable {
    public let driveID: String
    public let itemID: String

    public init(driveID: String, itemID: String) {
        self.driveID = driveID
        self.itemID = itemID
    }

    public var identityURL: URL {
        URL(string: "musicloud://onedrive")!.appending(component: driveID).appending(component: itemID)
    }
}
