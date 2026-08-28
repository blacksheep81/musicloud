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

Albums have a cover grid and track detail view. Covers load from embedded artwork
or a neighboring `cover.jpg`, `cover.png`, `folder.jpg`, or `folder.png` file.
Albums currently group by album title and directory, with natural filename order;
multi-disc merging and disc/track-number tag ordering are not implemented yet.

The session queue supports play next, append, play now, moving entries, removing
entries, and clearing upcoming tracks. Repeated songs have independent queue
entries. Queue edits never delete audio files; the queue is not restored on restart.
Starting a song replaces the queue with the remaining songs in its visible list.

Keyboard navigation: Command-1/2 switches albums/songs, Command-Shift-L toggles
the queue, and Command-Shift-E adds the open album to the queue. Album tiles
support Tab focus and Return to open.

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
