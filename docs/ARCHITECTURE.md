# Architecture decisions

## macOS first

Use SwiftUI for the first working macOS slice and AVFoundation for playback.
Keep MusicloudCore free of AppKit, SwiftUI, and AVFoundation. It currently owns
track models, library merging, search, and the future music-source contract.
The initial local JSON store is intentionally small; move to SQLite when cloud
indexing and larger libraries justify it.

## Cloud sources

MusicSource is a contract only, not a working cloud integration. Provider records
will need provider/account/item identifiers, revision and cache identity. Local
Track uses a file URL today and will be migrated when the first provider lands.
Never persist expiring direct links as track identity. Providers must support
pagination and cancellable requests. Authentication belongs in platform adapters;
no passwords, access tokens, or private account details belong in the repository.

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
