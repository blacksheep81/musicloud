import AVFoundation
import AudioToolbox
import ImageIO

public enum ArtworkLoader {
    public static func load(_ url: URL, maximumSize: Int = 640) async -> CGImage? {
        guard maximumSize > 0, !Task.isCancelled else { return nil }
        let asset = AVURLAsset(url: url)
        if let metadata = try? await asset.load(.metadata) {
            for entry in metadata where entry.commonKey == .commonKeyArtwork {
                if Task.isCancelled { return nil }
                if let data = try? await entry.load(.dataValue),
                   let source = CGImageSourceCreateWithData(data as CFData, nil),
                   let image = thumbnail(source, maximumSize: maximumSize) { return image }
            }
        }
        if !Task.isCancelled, let image = audioFileArtwork(url, maximumSize: maximumSize) { return image }
        if !Task.isCancelled, url.pathExtension.lowercased() == "flac",
           let data = FLACArtwork.read(url),
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let image = thumbnail(source, maximumSize: maximumSize) { return image }
        let directory = url.deletingLastPathComponent()
        for name in ["cover.jpg", "cover.png", "folder.jpg", "folder.png", "Cover.jpg", "Folder.jpg"] {
            if Task.isCancelled { return nil }
            let path = directory.appending(path: name)
            guard FileManager.default.fileExists(atPath: path.path) else { continue }
            if let source = CGImageSourceCreateWithURL(path as CFURL, nil),
               let image = thumbnail(source, maximumSize: maximumSize) { return image }
        }
        return nil
    }

    private static func audioFileArtwork(_ url: URL, maximumSize: Int) -> CGImage? {
        var file: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &file) == noErr, let file else { return nil }
        defer { AudioFileClose(file) }
        // This property transfers ownership of the CFData to the caller.
        var artwork: Unmanaged<CFData>?
        var size = UInt32(MemoryLayout<Unmanaged<CFData>?>.size)
        let status = AudioFileGetProperty(file, kAudioFilePropertyAlbumArtwork, &size, &artwork)
        guard let data = artwork?.takeRetainedValue(), status == noErr,
              let source = CGImageSourceCreateWithData(data, nil) else { return nil }
        return thumbnail(source, maximumSize: maximumSize)
    }

    private static func thumbnail(_ source: CGImageSource, maximumSize: Int) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary)
    }
}
