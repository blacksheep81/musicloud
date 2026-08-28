import AppKit
import AVFoundation
import MusicloudCore
import MusicloudAudio
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PlayerModel: ObservableObject {
    @Published var tracks: [Track] = [] {
        didSet { albums = Album.grouping(tracks) }
    }
    @Published private(set) var albums: [Album] = []
    @Published var queue = PlaybackQueue()
    var current: Track? { queue.current?.track }
    @Published var isPlaying = false
    @Published var isPreparing = false
    let oneDrive = OneDriveModel()
    @Published var isImporting = false
    @Published var importProgress: ImportProgress?
    @Published var importSummary: String?
    @Published var elapsed = 0.0
    @Published var duration = 0.0
    @Published var error: String?
    @Published var volume = 0.8 {
        didSet { player.volume = Float(volume) }
    }

    private let player = AVPlayer()
    private var timer: Any?
    private var ended: NSObjectProtocol?
    private var failed: NSObjectProtocol?
    private var stateObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private let libraryURL: URL
    private var importTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var playbackVersion = 0

    init() {
        libraryURL = URL.applicationSupportDirectory
            .appending(path: "musicloud/library.json")
        do {
            if FileManager.default.fileExists(atPath: libraryURL.path) {
                tracks = try JSONDecoder().decode([Track].self, from: Data(contentsOf: libraryURL))
            }
        } catch {
            self.error = "Library could not be read: \(error.localizedDescription)"
        }
        albums = Album.grouping(tracks)
        player.volume = Float(volume)
        timer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.elapsed = time.seconds.isFinite ? time.seconds : 0
                let seconds = self.player.currentItem?.duration.seconds ?? 0
                self.duration = seconds.isFinite ? max(0, seconds) : 0
            }
        }
        stateObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = self.player.timeControlStatus == .playing
            }
        }
    }

    func importFiles() {
        guard !isImporting else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["wav", "flac", "m4a", "mp3", "aif", "aiff", "aac"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.prompt = "Import"
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        let existing = Set(tracks.map(\.url))
        isImporting = true
        importProgress = nil
        importSummary = nil
        importTask = Task {
            defer {
                isImporting = false
                importProgress = nil
                importTask = nil
            }
            do {
                let result = try await LocalImporter.run(roots: urls, excluding: existing) { [weak self] progress in
                    await self?.updateImportProgress(progress)
                }
                try Task.checkCancellation()
                let previousCount = tracks.count
                tracks = Library.merging(tracks, with: result.tracks)
                if tracks.count != previousCount { persist() }
                importSummary = "\(tracks.count - previousCount) tracks added"
                if !result.issues.isEmpty {
                    error = "\(result.issues.count) import issues:\n" + result.issues.prefix(5).joined(separator: "\n")
                }
            } catch is CancellationError {
                importSummary = "Import cancelled"
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func cancelImport() { importTask?.cancel() }

    private func updateImportProgress(_ progress: ImportProgress) {
        importProgress = progress
    }

    func play(_ track: Track, in context: [Track]? = nil) {
        queue.start(context ?? tracks, at: track.id)
        startPlayback(track)
    }

    func enqueue(_ tracks: [Track], next: Bool = false) {
        queue.enqueue(tracks, next: next)
    }

    func playQueued(_ id: UUID) {
        if let track = queue.playNow(id) { startPlayback(track) }
    }

    func addCloudTracks(_ additions: [Track]) {
        let count = tracks.count
        tracks = Library.merging(tracks, with: additions)
        importSummary = "\(tracks.count - count) cloud tracks added"
        if tracks.count != count { persist() }
    }

    func stopCloudPlayback() {
        guard current?.cloud != nil else { return }
        playbackVersion += 1
        playbackTask?.cancel()
        isPreparing = false
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    private func startPlayback(_ track: Track) {
        playbackVersion += 1
        let version = playbackVersion
        playbackTask?.cancel()
        isPreparing = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        elapsed = 0
        duration = 0
        if let ended { NotificationCenter.default.removeObserver(ended) }
        if let failed { NotificationCenter.default.removeObserver(failed) }
        itemObservation = nil
        if let reference = track.cloud {
            isPreparing = true
            playbackTask = Task {
                defer { if version == playbackVersion { isPreparing = false; playbackTask = nil } }
                do {
                    let url = try await oneDrive.playbackURL(reference)
                    try Task.checkCancellation()
                    guard version == playbackVersion else { return }
                    activatePlayback(url)
                } catch is CancellationError {}
                catch { if version == playbackVersion { self.error = error.localizedDescription } }
            }
            return
        }
        guard track.url.isFileURL, FileManager.default.fileExists(atPath: track.url.path) else {
            error = "File is missing: \(track.url.lastPathComponent)"
            return
        }
        activatePlayback(track.url)
    }

    private func activatePlayback(_ url: URL) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "This audio file could not be played."
            Task { @MainActor [weak self] in
                guard let self, self.player.currentItem === item else { return }
                self.error = message
            }
        }
        ended = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.player.currentItem === item else { return }
                self.next(automatically: true)
            }
        }
        failed = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.player.currentItem === item else { return }
                self.player.pause()
                self.error = "Playback stopped because the audio could not be read."
            }
        }
        player.play()
    }

    func togglePlayback() {
        guard !isPreparing else { return }
        guard current != nil else {
            if let queued = queue.advance() { startPlayback(queued) }
            else if let first = tracks.first { play(first) }
            return
        }
        if player.currentItem == nil, let current { startPlayback(current); return }
        if player.timeControlStatus == .paused {
            if duration > 0 && elapsed >= duration - 0.2 { seek(0) }
            player.play()
        } else {
            player.pause()
        }
    }

    func next(automatically: Bool = false) {
        if let next = queue.advance() {
            startPlayback(next)
        } else if automatically {
            player.pause()
        }
    }

    func previous() {
        guard current != nil else { return }
        if elapsed > 3 || queue.history.isEmpty { seek(0) }
        else if let previous = queue.previous() { startPlayback(previous) }
    }

    func seek(_ seconds: Double) {
        player.seek(to: CMTime(seconds: max(0, min(seconds, duration)), preferredTimescale: 600))
    }

    func remove(_ ids: Set<URL>) {
        if let current, ids.contains(current.id) {
            playbackVersion += 1
            playbackTask?.cancel()
            isPreparing = false
            player.pause()
            player.replaceCurrentItem(with: nil)
            duration = 0
            elapsed = 0
        }
        queue.removeTracks(ids)
        tracks.removeAll { ids.contains($0.id) }
        persist()
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: libraryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(tracks).write(to: libraryURL, options: .atomic)
        } catch {
            self.error = "Library could not be saved: \(error.localizedDescription)"
        }
    }
}
