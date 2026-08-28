# Architecture decisions

## macOS first

Use SwiftUI for the first working macOS slice and AVFoundation for playback.
Keep MusicloudCore free of AppKit, SwiftUI, and AVFoundation. It currently owns
track models, library merging, search, and the future music-source contract.
The initial local JSON store is intentionally small; move to SQLite when cloud
indexing and larger libraries justify it.

MusicloudAudio owns the platform audio import adapter. LocalImporter runs folder
enumeration and metadata processing in a cancellable utility task, validates
playability, and emits progress. The UI commits the batch only on successful
completion. AVAsset's full metadata collection is used because commonMetadata
does not expose the generated WAV/FLAC fixtures' tags on the tested macOS version.
LocalScanner canonicalizes file URLs and avoids nested symlink traversal.

PlaybackQueue owns current, upcoming, and history entries in MusicloudCore.
Every entry has an independent UUID so repeating a song does not collapse queue
controls. The player follows this queue instead of indexing the library. Late
AVPlayerItem notifications are ignored after the active item changes.

Album grouping is title plus directory, deliberately preserving compilations in
one folder and separating different editions in different folders. Track order
uses natural filename sorting until disc/track tag support is added.

Artwork is downsampled by ImageIO and cached in a bounded NSCache. System metadata
and AudioToolbox are tried first. Native FLAC PICTURE blocks have a bounded fallback
reader following [RFC 9639 section 8.8](https://www.rfc-editor.org/rfc/rfc9639.html#section-8.8),
because the tested native APIs omit that fixture's cover. It does not decode audio
or retrieve linked image URIs. The reader caps block iteration and metadata traversal,
checks lengths against the file/block, and prefers front-cover pictures.

## Cloud sources

MusicSource remains a generic future-provider contract. The first concrete
OneDriveService lives in MusicloudCloud, with an injectable HTTP transport and
token vault. Track now has an optional CloudTrackReference; old local JSON decodes
without migration. Cloud identity uses drive/item IDs, while a synthetic URL
preserves folder grouping and the filename. Revision/cache identities are pending.
Never persist expiring direct links as track identity. Providers must support
pagination and cancellable requests. Authentication belongs in platform adapters;
no passwords, access tokens, or private account details belong in the repository.
The OneDrive session actor shares refresh work, rejects unsafe pagination origins,
and invalidates pending results on disconnect. Playback URL resolution is cancelled
when the player switches tracks; the library only stores stable references.

## Cross-platform tradeoff

Native SwiftUI makes the macOS milestone smaller but does not deliver portable UI.
The separation provides specifications and test cases for a later Rust core;
it is not automatic code reuse. Reassess this choice before the cloud layer grows.

## Visual direction

Compact translucent sidebar, clear typography, album artwork from imported music,
restrained accent color, and a fixed bottom transport. No copied upstream assets
or code. Album layouts and lyrics follow after reliable playback.

## Validation boundaries

Unit tests cover domain behavior. A successful build does not establish audible
playback, codec completeness, polished UI, or cloud access. Verify these separately.
