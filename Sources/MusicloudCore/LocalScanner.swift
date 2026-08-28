import Foundation

public struct ScanResult: Sendable {
    public var urls: [URL] = []
    public var issues: [String] = []
}

public enum LocalScanner {
    // Run on a worker task. Nested symlinks are skipped to avoid cycles and
    // accidentally scanning folders outside the user's selected directory.
    public static func scan(_ roots: [URL], excluding: Set<URL> = []) throws -> ScanResult {
        let manager = FileManager.default
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey]
        var result = ScanResult()
        var seen = Set(excluding.map { $0.standardizedFileURL.resolvingSymlinksInPath() })
        var visitedDirectories = Set<URL>()

        func addFile(_ url: URL, values: URLResourceValues) {
            guard values.isRegularFile == true, values.isSymbolicLink != true, Track.supports(url) else { return }
            let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
            if seen.insert(canonical).inserted { result.urls.append(canonical) }
        }

        for root in roots {
            try Task.checkCancellation()
            guard root.isFileURL else {
                result.issues.append("Not a local file: \(root.lastPathComponent)")
                continue
            }
            let root = root.standardizedFileURL.resolvingSymlinksInPath()
            do {
                let values = try root.resourceValues(forKeys: keys)
                guard values.isDirectory == true else {
                    addFile(root, values: values)
                    continue
                }
                guard visitedDirectories.insert(root).inserted else { continue }
                guard let enumerator = manager.enumerator(
                    at: root, includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { url, error in
                        result.issues.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        return true
                    }
                ) else {
                    result.issues.append("Could not scan \(root.lastPathComponent)")
                    continue
                }
                for case let url as URL in enumerator {
                    try Task.checkCancellation()
                    do {
                        let values = try url.resourceValues(forKeys: keys)
                        if values.isSymbolicLink == true {
                            continue
                        } else if values.isDirectory == true {
                            if !visitedDirectories.insert(url.standardizedFileURL).inserted { enumerator.skipDescendants() }
                        } else {
                            addFile(url, values: values)
                        }
                    } catch {
                        result.issues.append("\(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                result.issues.append("\(root.lastPathComponent): \(error.localizedDescription)")
            }
        }
        result.urls.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        return result
    }
}
