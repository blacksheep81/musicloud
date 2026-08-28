import Foundation
import Testing
@testable import MusicloudCore

@Test func acceptsLosslessFilesCaseInsensitively() {
    #expect(Track.supports(URL(fileURLWithPath: "/music/Track.FLAC")))
    #expect(Track.supports(URL(fileURLWithPath: "/music/Track.wav")))
    #expect(!Track.supports(URL(fileURLWithPath: "/music/cover.jpg")))
}

@Test func mergingDeduplicatesAndPreservesQueueOrder() {
    let a = Track(url: URL(fileURLWithPath: "/a.flac"))
    let b = Track(url: URL(fileURLWithPath: "/b.wav"))
    #expect(Library.merging([a], with: [a, b, b]) == [a, b])
}

@Test func searchIncludesMetadataAndFormat() {
    let track = Track(url: URL(fileURLWithPath: "/song.flac"), artist: "Bach", album: "Cello Suites")
    #expect(track.matches("bach"))
    #expect(track.matches("Cello"))
    #expect(track.matches("FLAC"))
    #expect(!track.matches("Mozart"))
}

@Test func libraryRoundTrips() throws {
    let original = [Track(url: URL(fileURLWithPath: "/music/a track.wav"))]
    let encoded = try JSONEncoder().encode(original)
    #expect(try JSONDecoder().decode([Track].self, from: encoded) == original)
}
