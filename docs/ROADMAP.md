# Roadmap

## 0.1 - Local macOS foundation (in progress)

- [x] Swift package and platform-independent domain target
- [x] Local file import with duplicate detection
- [x] Metadata, embedded artwork, and library search
- [x] Local library persistence
- [x] Playback, queue navigation, seek, and volume
- [ ] Listening and visual QA on real WAV/FLAC files
- [x] Folder import and background scanning, progress and cancellation
- [x] Generated WAV/FLAC decode, metadata and muted playback/seek tests
- [x] Folder import, repeat import and restart persistence UI checks
- [ ] Album and artist views, queue editing
- [ ] App bundle, app icon, and media-key integration

## 0.2 - OneDrive

- Register a desktop OAuth application with Microsoft
- Browser-based authentication with PKCE; tokens in Keychain
- Folder selection, paginated enumeration, incremental indexing
- Resolve expiring download links at playback time
- Range requests, retry handling, seek, and bounded disk cache
- Integration tests for expiration, rate limits, and network loss

## 0.3 - Google Drive and WebDAV

- Google desktop OAuth with minimum necessary scopes
- Keychain tokens, refresh handling, pagination and folder selection
- Reuse the provider/cache boundary; do not hardcode user accounts
- Add WebDAV for compatible NAS/cloud gateways

## 0.4 - Listening experience

- Lyrics, favorites, playlists, offline availability
- WAV/FLAC codec and seek fixture matrix
- Evaluate a shared audio engine for gapless and ReplayGain
- Accessibility, performance, signed/notarized macOS release

## Later - Linux and Windows

Prototype the shared core and audio engine before selecting the desktop UI.
SwiftUI is macOS-only: Windows/Linux will need a separate UI or a migration.
Evaluate Rust core plus GPUI/Tauri against build, audio, accessibility, and
packaging requirements. Do not promise one-codebase portability at this stage.
