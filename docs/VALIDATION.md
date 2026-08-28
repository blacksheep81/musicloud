# Validation

Environment: Apple Silicon macOS, Swift 6.2.3 Command Line Tools.

- `swift build --product Musicloud`: passed.
- Twenty-nine Swift Testing tests passed, including a parameterized WAV/FLAC test.
  Run with `bash scripts/test.sh`.
- Domain tests cover supported extensions, duplicate merging/order, search,
  library JSON round-trip, nested folder scans, hidden files, symlink loops,
  overlapping roots, missing roots, and cancellation.
- Audio tests decode generated two-second stereo 48 kHz WAV/FLAC fixtures,
  verify metadata, reject damaged audio, and check import progress/exclusions.
- Muted AVPlayer tests confirm playback time advances and seek reaches 1 second
  for both fixtures. This is not a subjective listening or bit-perfect test.
- Queue tests cover context playback, history, duplicate entries, reordering,
  removal, clearing, immediate playback, and library removal consistency.
- Album tests cover folder separation, compilations, and natural filename order.
- Artwork tests cover embedded FLAC, sidecar JPEG, thumbnail sizing, absent artwork,
  truncated picture fields, oversized length fields, and rejection of linked URIs.
- OneDrive mock tests cover PKCE, callback state/shape validation, code exchange,
  shared token refresh, one-time HTTP 401 retry, revocation, disconnect races,
  trusted pagination, account isolation, HTTPS download URLs, stable cloud IDs,
  and backward-compatible local library decoding. No real tokens are used.
- `bash scripts/package-app.sh`: passed; local unsigned app bundle created.
- `plutil -lint packaging/Info.plist` and shell syntax check: passed.
- App bundle opened; accessibility tree and screenshot confirmed the empty
  library window, import buttons, search, and disabled transport controls.
- Folder picker imported the generated fixture directory: two songs with correct
  titles/artists and WAV/FLAC formats appeared.
- Reimporting the same directory added zero songs; restarting restored both songs.
- Updated library screenshot checked at the default 1100 x 740 window size.
- Album grid and album detail screenshots verified with the generated test-pattern
  cover visible; Tab and Return successfully opened the album.
- Queue inspector opening and empty state verified using Command-Shift-L.
- Command-Shift-E added both album tracks; the queue displayed two independent
  entries with play, move, and remove controls in the detail/inspector layout.
- OneDrive sidebar and configuration sheet opened in the packaged app; an absent
  or invalid Client ID leaves Connect disabled. No browser login was initiated.
- AX click automation closed its connection; keyboard menu navigation worked and
  completed the folder-import checks.

Not yet verified: subjective listening on real music, the full codec/sample-rate
matrix, all queue controls via UI, UI seek controls, minimum-size layout, or cloud playback.
OneDrive still needs a registered Client ID, real OAuth/Keychain verification,
live folder browsing, and remote WAV/FLAC streaming/seek tests.
No user music or account credentials are committed. The local development library
contains two generated Musicloud Test Tone entries from the UI checks.

## Native UI Refresh

- Rebuilt and packaged the Folia-inspired dark UI; all 29 tests still pass.
- Checked actual 1100 x 740 window screenshots for library, songs, now playing,
  and the expanded queue panel. No overlapping controls were observed.
- Command-P selected the first fixture; playback eventually advanced through
  both fixtures and the WAV duration/position reached two seconds.
- Artwork and playback initially stalled while the media framework was opening
  local files, then loaded successfully. The cause of that initial delay is not
  established; this does not constitute a startup performance guarantee.
- Searching for FLAC reduced the two-track table to one result.
- Now playing currently has a lyrics empty state only, not a lyric renderer.
- Minimum-window sizing and all mouse interactions still need manual validation.
