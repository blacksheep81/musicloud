# Validation

Environment: Apple Silicon macOS, Swift 6.2.3 Command Line Tools.

- `swift build --product Musicloud`: passed.
- Twelve Swift Testing tests passed, including a parameterized WAV/FLAC test.
  Run with `bash scripts/test.sh`.
- Domain tests cover supported extensions, duplicate merging/order, search,
  library JSON round-trip, nested folder scans, hidden files, symlink loops,
  overlapping roots, missing roots, and cancellation.
- Audio tests decode generated two-second stereo 48 kHz WAV/FLAC fixtures,
  verify metadata, reject damaged audio, and check import progress/exclusions.
- Muted AVPlayer tests confirm playback time advances and seek reaches 1 second
  for both fixtures. This is not a subjective listening or bit-perfect test.
- `bash scripts/package-app.sh`: passed; local unsigned app bundle created.
- `plutil -lint packaging/Info.plist` and shell syntax check: passed.
- App bundle opened; accessibility tree and screenshot confirmed the empty
  library window, import buttons, search, and disabled transport controls.
- Folder picker imported the generated fixture directory: two songs with correct
  titles/artists and WAV/FLAC formats appeared.
- Reimporting the same directory added zero songs; restarting restored both songs.
- Updated library screenshot checked at the default 1100 x 740 window size.
- AX click automation closed its connection; keyboard menu navigation worked and
  completed the folder-import checks.

Not yet verified: subjective listening on real music, the full codec/sample-rate
matrix, embedded artwork, UI seek controls, minimum-size layout, or cloud playback.
No user music or account credentials are committed. The local development library
contains two generated Musicloud Test Tone entries from the UI checks.
