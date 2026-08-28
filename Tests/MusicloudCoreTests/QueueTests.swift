import Foundation
import Testing
@testable import MusicloudCore

private func track(_ name: String, album: String = "Album", artist: String = "Artist") -> Track {
    Track(url: URL(fileURLWithPath: "/music/\(name).flac"), artist: artist, album: album)
}

@Test func queueUsesContextAndKeepsPlaybackHistory() {
    let a = track("a"), b = track("b"), c = track("c")
    var queue = PlaybackQueue()
    queue.start([a, b, c], at: b.id)
    #expect(queue.current?.track == b)
    #expect(queue.upcoming.map(\.track) == [c])
    #expect(queue.previous() == nil)
    #expect(queue.advance() == c)
    #expect(queue.previous() == b)
    #expect(queue.upcoming.map(\.track) == [c])
    #expect(queue.advance() == c)
    #expect(queue.advance() == nil)
    #expect(queue.current?.track == c)
}

@Test func queueAllowsDuplicatesAndMovesIndividualEntries() throws {
    let a = track("a"), b = track("b"), c = track("c")
    var queue = PlaybackQueue()
    queue.start([a, b], at: a.id)
    queue.enqueue([c, a], next: true)
    queue.enqueue([b])
    #expect(queue.upcoming.map(\.track) == [c, a, b, b])
    let last = try #require(queue.upcoming.last)
    queue.move(last.id, by: -3)
    #expect(queue.upcoming.map(\.track) == [b, c, a, b])
    queue.remove(last.id)
    #expect(queue.upcoming.map(\.track) == [c, a, b])
    let first = try #require(queue.upcoming.first)
    queue.move(first.id, by: -1)
    #expect(queue.upcoming.first?.id == first.id)
    queue.clearUpcoming()
    #expect(queue.current?.track == a)
    #expect(queue.upcoming.isEmpty)
}

@Test func queueJumpAndLibraryRemovalStayConsistent() throws {
    let a = track("a"), b = track("b"), c = track("c")
    var queue = PlaybackQueue()
    queue.start([a, b, c], at: a.id)
    let last = try #require(queue.upcoming.last)
    #expect(queue.playNow(last.id) == c)
    #expect(queue.upcoming.map(\.track) == [b])
    #expect(queue.history.map(\.track) == [a])
    queue.removeTracks([a.id, c.id])
    #expect(queue.current == nil)
    #expect(queue.history.isEmpty)
    #expect(queue.advance() == b)
}

@Test func albumsGroupCompilationsAndKeepDifferentFoldersSeparate() throws {
    let a = track("02", artist: "One")
    let b = track("01", artist: "Two")
    let other = track("Other/01")
    let albums = Album.grouping([a, other, b])
    #expect(albums.count == 2)
    let compilation = try #require(albums.first { $0.tracks.count == 2 })
    #expect(compilation.artist == "Various Artists")
    #expect(compilation.tracks == [b, a])
    #expect(Album.grouping([]).isEmpty)
}
