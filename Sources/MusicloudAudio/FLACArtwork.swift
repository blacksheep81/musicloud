import Foundation

// Bounded PICTURE-block fallback for native FLAC; audio decoding stays in AVFoundation.
// Layout: https://www.rfc-editor.org/rfc/rfc9639.html#section-8.8
enum FLACArtwork {
    static func read(_ url: URL) -> Data? {
        guard let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        do {
            let end = try file.seekToEnd()
            try file.seek(toOffset: 0)
            guard try file.read(upToCount: 4) == Data("fLaC".utf8) else { return nil }
            var fallback: Data?
            for _ in 0..<4096 {
                guard !Task.isCancelled, try file.offset() < 128 * 1024 * 1024,
                      let header = try file.read(upToCount: 4), header.count == 4 else { return fallback }
                let length = Int(header[1]) << 16 | Int(header[2]) << 8 | Int(header[3])
                let offset = try file.offset()
                guard offset <= end, UInt64(length) <= end - offset else { return fallback }
                if header[0] & 0x7f == 6 {
                    guard let block = try file.read(upToCount: length), block.count == length else { return fallback }
                    if let picture = parse(block) {
                        if picture.type == 3 { return picture.data }
                        if fallback == nil { fallback = picture.data }
                    }
                } else {
                    try file.seek(toOffset: offset + UInt64(length))
                }
                if header[0] & 0x80 != 0 { return fallback }
            }
            return fallback
        } catch { return nil }
    }

    static func parse(_ block: Data) -> (type: Int, data: Data)? {
        var cursor = 0
        func bytes(_ count: Int) -> Data? {
            guard count >= 0, count <= block.count - cursor else { return nil }
            defer { cursor += count }
            return block.subdata(in: cursor..<(cursor + count))
        }
        func integer() -> Int? {
            guard let data = bytes(4) else { return nil }
            return data.reduce(0) { ($0 << 8) | Int($1) }
        }
        guard let type = integer(), let mimeLength = integer(),
              let mime = bytes(mimeLength), mime != Data("-->".utf8),
              let descriptionLength = integer(), bytes(descriptionLength) != nil,
              bytes(16) != nil, let imageLength = integer(), imageLength > 0,
              let image = bytes(imageLength), cursor == block.count else { return nil }
        return (type, image)
    }
}
