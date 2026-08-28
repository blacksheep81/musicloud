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

@Test func folderScanFindsNestedAudioAndSkipsHiddenFilesAndLinks() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appending(path: UUID().uuidString)
    try manager.createDirectory(at: root.appending(path: "Album"), withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: root) }
    let first = root.appending(path: "01.wav")
    let second = root.appending(path: "Album/02.FLAC")
    for file in [first, second, root.appending(path: ".hidden.mp3"), root.appending(path: "cover.jpg")] {
        try Data().write(to: file)
    }
    try manager.createSymbolicLink(at: root.appending(path: "Album/loop"), withDestinationURL: root)
    try manager.createSymbolicLink(at: root.appending(path: "alias.wav"), withDestinationURL: first)
    let scan = try LocalScanner.scan([root, first, root.appending(path: "Album")])
    #expect(scan.urls == [first, second].map { $0.resolvingSymlinksInPath() })
    #expect(scan.issues.isEmpty)
    let repeated = try LocalScanner.scan([root], excluding: Set(scan.urls))
    #expect(repeated.urls.isEmpty)
}

@Test func scanReportsMissingRootsWithoutLosingValidFiles() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appending(path: "song.wav")
    try Data().write(to: file)
    let result = try LocalScanner.scan([root.appending(path: "missing"), file])
    #expect(result.urls == [file.resolvingSymlinksInPath()])
    #expect(result.issues.count == 1)
}

@Test func scannerHonorsCancellation() async throws {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try LocalScanner.scan([URL(fileURLWithPath: "/")])
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled scan unexpectedly completed")
    } catch is CancellationError {
        // Expected: cancellation must stop before enumerating the root.
    }
}
