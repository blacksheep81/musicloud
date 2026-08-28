import AVFoundation
import Foundation
import Testing
@testable import MusicloudAudio

private func fixture(_ ext: String) throws -> URL {
    try #require(Bundle.module.url(forResource: "tone", withExtension: ext, subdirectory: "Fixtures"))
}

@Test(arguments: ["wav", "flac"])
func decodesLosslessFixture(_ ext: String) async throws {
    let url = try fixture(ext)
    let audio = try AVAudioFile(forReading: url)
    #expect(audio.processingFormat.sampleRate == 48_000)
    #expect(audio.processingFormat.channelCount == 2)
    #expect(audio.length == 96_000)
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 4096))
    try audio.read(into: buffer)
    let samples = try #require(buffer.floatChannelData)
    #expect((0..<Int(buffer.frameLength)).contains { abs(samples[0][$0]) > 0.001 })
    let result = try await LocalImporter.run(roots: [url, url], excluding: []) { _ in }
    #expect(result.tracks.count == 1)
    #expect(result.tracks.first?.title == "Musicloud Test Tone")
    #expect(result.tracks.first?.artist == "Musicloud")
    #expect(result.issues.isEmpty)
}

@Test @MainActor
func playerAdvancesAndSeeksWithLosslessFixtures() async throws {
    for ext in ["wav", "flac"] {
        let item = AVPlayerItem(url: try fixture(ext))
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        defer { player.pause(); player.replaceCurrentItem(with: nil) }
        player.play()
        let deadline = Date().addingTimeInterval(8)
        while player.currentTime().seconds < 0.15 && item.status != .failed && Date() < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        #expect(item.status == .readyToPlay)
        #expect(player.currentTime().seconds >= 0.15)
        player.pause()
        let sought = await player.seek(to: CMTime(seconds: 1, preferredTimescale: 48_000), toleranceBefore: .zero, toleranceAfter: .zero)
        #expect(sought)
        #expect(abs(player.currentTime().seconds - 1) < 0.05)
    }
}

@Test func importerRejectsDamagedAudio() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appending(path: "broken.flac")
    try Data("not audio".utf8).write(to: file)
    let result = try await LocalImporter.run(roots: [root], excluding: []) { _ in }
    #expect(result.tracks.isEmpty)
    #expect(result.issues.count == 1)
}

@Test func importerPropagatesCancellation() async throws {
    let url = try fixture("flac")
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try await LocalImporter.run(roots: [url], excluding: []) { _ in }
    }
    do {
        _ = try await task.value
        Issue.record("Cancelled import unexpectedly completed")
    } catch is CancellationError {}
}

private actor ProgressRecorder {
    var values: [ImportProgress] = []
    func append(_ value: ImportProgress) { values.append(value) }
}

@Test func artworkUsesSidecarAndResizesIt() async throws {
    let image = try #require(await ArtworkLoader.load(fixture("wav"), maximumSize: 120))
    #expect(image.width == 120)
    #expect(image.height == 120)
}

@Test func artworkUsesEmbeddedCoverWithoutSidecar() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appending(path: "test.flac")
    try FileManager.default.copyItem(at: fixture("flac"), to: file)
    let image = try #require(await ArtworkLoader.load(file, maximumSize: 80))
    #expect(image.width == 80)
    #expect(image.height == 80)
    let noCover = root.appending(path: "test.wav")
    try FileManager.default.copyItem(at: fixture("wav"), to: noCover)
    #expect(await ArtworkLoader.load(noCover) == nil)
}

@Test func flacPictureRejectsTruncationAndExternalLinks() {
    func integer(_ value: UInt32) -> Data {
        var big = value.bigEndian
        return withUnsafeBytes(of: &big) { Data($0) }
    }
    let image = Data([1, 2, 3])
    let valid = integer(3) + integer(10) + Data("image/jpeg".utf8) + integer(0)
        + Data(repeating: 0, count: 16) + integer(3) + image
    #expect(FLACArtwork.parse(valid)?.data == image)
    for length in 0..<valid.count { #expect(FLACArtwork.parse(Data(valid.prefix(length))) == nil) }
    let linked = integer(3) + integer(3) + Data("-->".utf8) + integer(0)
        + Data(repeating: 0, count: 16) + integer(3) + image
    #expect(FLACArtwork.parse(linked) == nil)
    #expect(FLACArtwork.parse(integer(3) + integer(.max)) == nil)
}

@Test func importerReportsProgressAndSkipsExistingTracks() async throws {
    let wav = try fixture("wav")
    let flac = try fixture("flac")
    let recorder = ProgressRecorder()
    let result = try await LocalImporter.run(roots: [wav, flac, flac], excluding: [wav]) {
        await recorder.append($0)
    }
    #expect(result.tracks.map(\.url) == [flac.resolvingSymlinksInPath()])
    let progress = await recorder.values
    #expect(progress.map(\.completed) == [0, 1])
    #expect(progress.allSatisfy { $0.total == 1 })
}
