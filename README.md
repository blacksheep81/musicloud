# musicloud

A macOS-first music player for a personal local and cloud music library.
Working name: **musicloud**.

## Status

Initial native macOS prototype. Local file/folder import, metadata/artwork loading,
search, persisted library, queue navigation, playback, seeking, and volume controls.
Playback uses AVFoundation; supported extensions are WAV, FLAC, M4A, MP3,
AIFF, and AAC. Actual decoding depends on the file and macOS; this is not a
bit-perfect, exclusive-output, or gapless playback claim.

**OneDrive and Google Drive are planned, not implemented.**

Folder import scans subfolders in the background, skips hidden files and nested
symbolic links, filters duplicates before reading metadata, and reports progress.
Cancel discards the current import batch; existing library entries are unchanged.
Damaged or unsupported audio files are skipped with an error summary.

## Development

Requires macOS 14+ and Swift 6 (Xcode or Command Line Tools).

```sh
bash scripts/test.sh
swift run Musicloud
```

The test script handles the Testing framework search path and missing optional
Foundation overlay in Command Line Tools installations. With full Xcode it runs
`swift test` directly. Tests include generated WAV/FLAC fixtures and muted
AVPlayer playback/seek checks; they do not access personal music.

To create a local unsigned app bundle:

```sh
bash scripts/package-app.sh
open dist/Musicloud.app
```

The library is stored in `~/Library/Application Support/musicloud/library.json`.
Imported audio files stay in their original locations and are not uploaded or copied.
This development app is not sandboxed or signed. Distribution,
sandbox bookmarks, signing, and notarization are later milestones.

## Direction

Inspired by the visual care of [Hummingbird](https://github.com/hummingbird-player/hummingbird)
and the multi-source concept of [Primuse](https://github.com/chenqi92/primuse).
This is an independent implementation; neither project's code or assets are included.

See [the roadmap](docs/ROADMAP.md) and [architecture decisions](docs/ARCHITECTURE.md).

## License

Released under the [MIT License](LICENSE).
