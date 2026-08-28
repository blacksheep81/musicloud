# musicloud

A macOS-first music player for a personal local and cloud music library.
Working name: **musicloud**.

## Status

Initial native macOS prototype. Local file import, metadata/artwork loading,
search, persisted library, queue navigation, playback, seeking, and volume controls.
Playback uses AVFoundation; supported extensions are WAV, FLAC, M4A, MP3,
AIFF, and AAC. Actual decoding depends on the file and macOS; this is not a
bit-perfect, exclusive-output, or gapless playback claim.

**OneDrive and Google Drive are planned, not implemented.**

## Development

Requires macOS 14+ and Swift 6 (Xcode or Command Line Tools).

```sh
swift test
swift run Musicloud
```

If a Command Line Tools installation reports `no such module 'Testing'`, use:

```sh
swift test \
  -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
  -Xlinker -F -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks
```

This also disables the optional Foundation testing overlay, which is missing
from some Command Line Tools installations.

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
