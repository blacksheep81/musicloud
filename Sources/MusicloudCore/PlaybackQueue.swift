import Foundation

public struct QueueEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let track: Track

    public init(track: Track) {
        id = UUID()
        self.track = track
    }
}

public struct PlaybackQueue: Sendable {
    public private(set) var current: QueueEntry?
    public private(set) var upcoming: [QueueEntry] = []
    public private(set) var history: [QueueEntry] = []

    public init() {}

    public mutating func start(_ tracks: [Track], at trackID: URL) {
        guard let index = tracks.firstIndex(where: { $0.id == trackID }) else { return }
        current = QueueEntry(track: tracks[index])
        history = []
        upcoming = tracks.dropFirst(index + 1).map(QueueEntry.init)
    }

    public mutating func enqueue(_ tracks: [Track], next: Bool = false) {
        let entries = tracks.map(QueueEntry.init)
        if next { upcoming.insert(contentsOf: entries, at: 0) }
        else { upcoming.append(contentsOf: entries) }
    }

    @discardableResult public mutating func advance() -> Track? {
        guard !upcoming.isEmpty else { return nil }
        if let current { history.append(current) }
        current = upcoming.removeFirst()
        return current?.track
    }

    @discardableResult public mutating func previous() -> Track? {
        guard let previous = history.popLast() else { return nil }
        if let current { upcoming.insert(current, at: 0) }
        current = previous
        return previous.track
    }

    public mutating func move(_ id: UUID, by offset: Int) {
        guard let index = upcoming.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard upcoming.indices.contains(destination) else { return }
        let entry = upcoming.remove(at: index)
        upcoming.insert(entry, at: destination)
    }

    public mutating func remove(_ id: UUID) { upcoming.removeAll { $0.id == id } }
    @discardableResult public mutating func playNow(_ id: UUID) -> Track? {
        guard let index = upcoming.firstIndex(where: { $0.id == id }) else { return nil }
        if let current { history.append(current) }
        current = upcoming.remove(at: index)
        return current?.track
    }
    public mutating func clearUpcoming() { upcoming.removeAll() }

    public mutating func removeTracks(_ ids: Set<URL>) {
        upcoming.removeAll { ids.contains($0.track.id) }
        history.removeAll { ids.contains($0.track.id) }
        if let current, ids.contains(current.track.id) { self.current = nil }
    }
}
