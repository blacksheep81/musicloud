import AppKit
import AVFoundation
import MusicloudCore
import MusicloudAudio
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PlayerModel: ObservableObject {
    @Published var tracks: [Track] = []
    @Published var current: Track?
    @Published var artwork: NSImage?
    @Published var isPlaying = false
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

    func play(_ track: Track) {
        guard FileManager.default.fileExists(atPath: track.url.path) else {
            error = "File is missing: \(track.url.lastPathComponent)"
            return
        }
        if let ended { NotificationCenter.default.removeObserver(ended) }
        if let failed { NotificationCenter.default.removeObserver(failed) }
        itemObservation = nil
        current = track
        artwork = nil
        elapsed = 0
        duration = 0
        let item = AVPlayerItem(url: track.url)
        player.replaceCurrentItem(with: item)
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "This audio file could not be played."
            Task { @MainActor [weak self] in self?.error = message }
        }
        ended = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.next(automatically: true) }
        }
        failed = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.player.pause()
                self?.error = "Playback stopped because the audio could not be read."
            }
        }
        player.play()
        Task {
            guard let metadata = try? await item.asset.load(.metadata) else { return }
            for entry in metadata where entry.commonKey == .commonKeyArtwork {
                if let data = try? await entry.load(.dataValue), current?.id == track.id {
                    artwork = NSImage(data: data)
                }
            }
        }
    }

    func togglePlayback() {
        guard current != nil else {
            if let first = tracks.first { play(first) }
            return
        }
        if player.timeControlStatus == .paused {
            if duration > 0 && elapsed >= duration - 0.2 { seek(0) }
            player.play()
        } else {
            player.pause()
        }
    }

    func next(automatically: Bool = false) {
        guard let current, let index = tracks.firstIndex(where: { $0.id == current.id }) else { return }
        if index + 1 < tracks.count {
            play(tracks[index + 1])
        } else if automatically {
            player.pause()
        }
    }

    func previous() {
        guard let current, let index = tracks.firstIndex(where: { $0.id == current.id }) else { return }
        if elapsed > 3 || index == 0 { seek(0) } else { play(tracks[index - 1]) }
    }

    func seek(_ seconds: Double) {
        player.seek(to: CMTime(seconds: max(0, min(seconds, duration)), preferredTimescale: 600))
    }

    func remove(_ ids: Set<URL>) {
        if let current, ids.contains(current.id) {
            player.pause()
            player.replaceCurrentItem(with: nil)
            self.current = nil
            artwork = nil
            duration = 0
            elapsed = 0
        }
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
