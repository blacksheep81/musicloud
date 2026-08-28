# Musicloud Fork

This directory contains a source-based derivative of Folia, not a SwiftUI
reimplementation. The original README, author metadata, contributors, source
comments, and AGPL-3.0 license are preserved.

Upstream: https://github.com/chthollyphile/folia-major
Imported commit: 5f1c966daf25b414c94a866e4c16418b084a26f5
Import date: 2026-08-28

## Changes to the Imported Baseline

- Musicloud package/product identity and browser title.
- Separate Electron profile and settings from Folia and the SwiftUI prototype.
- Upstream auto-updates disabled; fork release links point to musicloud.
- Development server binds to loopback; optional upstream commit-name lookup
  is off unless FOLIA_COMMIT_NAME_LOOKUP=true.
- Original player, local library, lyrics parsers, visualizers, and Navidrome
  integration retained. Some in-app labels and icons still identify Folia.
- Main home heading and English/Chinese welcome labels identify Musicloud.
  Help includes the fork's source link alongside the original author credit.

## Migration Validation

- Node 24 dependency installation and TypeScript check passed.
- Focused upstream tests: 211 passed, 1 skipped across lyrics, Navidrome,
  and update channels.
- Vite browser home rendered with no console errors at 1280 x 720.
- Electron development window launched and rendered the upstream home.
  KuGou returned a remote 502 during account-status probing; no account login
  or real cloud playback was tested.
- Original local playback and every visualizer have not yet been retested
  end-to-end in the fork. These inherited features are not new validation claims.

The inherited package version identifies the upstream baseline, not a Musicloud
release. No signed Musicloud Electron release has been published.

## Run

Requires Node 24 or newer. From this directory:

```sh
npm ci
npm run dev
# Desktop development, with the Vite server on port 3000:
npm run dev:electron
```

The new app does not automatically import the old SwiftUI library or credentials.
Reimport local music through Folia's existing library interface.

## Cloud Work

The home navigation now includes Cloud (云端). It lists NAS, OneDrive,
Google Drive and WebDAV. NAS configuration opens the existing Integration
settings; an enabled, configured Navidrome server has an Open Library action.
Configured does not mean a live connection has been verified.
OneDrive now has an experimental desktop connector; Google Drive and WebDAV
remain unavailable. Cloud selection persists across reloads and is available
through the command palette. See [OneDrive setup and limitations](docs/MUSICLOUD-ONEDRIVE.md).

Cloud UI validation: typecheck passed; 19 search/navigation and command registry
tests passed. Browser screenshots checked at 1280 x 720 and 390 x 844, with no
observed overlap. NAS settings navigation and Cloud restoration on reload
verified. No real NAS credentials or server were used.

The existing Navidrome/Subsonic integration can be used with a server hosted on
a NAS. This does not mean raw SMB or WebDAV folders are already supported.

Next milestones:

1. OneDrive: verify real Microsoft OAuth and cloud playback, then add streaming,
   cloud artwork/sidecar lyrics and cache controls. The first connector downloads
   files before playback, with a 128 MB per-file limit.
2. Google Drive: desktop OAuth and read-only file browsing, with equivalent
   credential isolation and playback behavior.
3. WebDAV NAS: HTTPS connection profiles, credential storage, directory listing,
   range requests, and explicit handling of local-network endpoints.

New OneDrive tokens never belong in renderer localStorage, synced settings, logs,
or committed configuration. Inherited Navidrome storage has not been migrated.
Reuse Folia's existing lyric parsers and playback
adapter boundaries; do not build another lyric renderer.

The Swift OneDrive implementation remains reference material; the Electron
connector uses Microsoft MSAL. Saved-session status is not a guarantee of current
server access. Real-account validation is still required before a stable release.
