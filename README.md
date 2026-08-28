# musicloud

A Folia-based desktop music player, extending its original interface and lyrics
system toward personal cloud libraries. macOS first, Windows and Linux later.

## Current Development

The active application is in **[desktop/](desktop/)**. It contains Folia's real
React/Electron source, local library, lyric parsers, visualizers, and existing
Navidrome integration. It is not the earlier SwiftUI look-alike.

See **[fork notes and setup](desktop/MUSICLOUD.md)** for provenance, local startup,
identity isolation, and the cloud implementation milestones.

- OneDrive has an experimental desktop connector: Microsoft login, folder browsing,
  library import and download-before-playback. Real-account verification is pending;
  see [OneDrive setup](desktop/docs/MUSICLOUD-ONEDRIVE.md). Google Drive is not implemented.
- NAS access through the inherited Navidrome/Subsonic integration is retained.
  Direct WebDAV and SMB support is not implemented.
- No signed Electron release or automatic updater is available yet.
- Upstream artwork, visual themes and some Folia labels are retained during
  migration; this is an independent derivative, not an official Folia release.

## Start

Requires Node 24+:

```sh
cd desktop
npm ci
npm run dev:electron
```

For browser-only development, use `npm run dev`. Default address:
http://127.0.0.1:3000. Browser and Electron file-access capabilities differ.

## Previous Prototype

The native SwiftUI implementation remains in `Sources/`, with its tests and
packaging scripts. Its original state is preserved on
`archive/swiftui-prototype` at commit `07d216b`.
See [the archived prototype guide](docs/SWIFTUI-PROTOTYPE.md).
Older architecture, roadmap and OneDrive documents under `docs/` describe that
prototype, not the active Electron app.

## License and Attribution

The Folia-derived application is distributed under [AGPL-3.0](LICENSE).
Upstream: [chthollyphile/folia-major](https://github.com/chthollyphile/folia-major),
commit `5f1c966daf25b414c94a866e4c16418b084a26f5`.
Original author notices and [contributors](desktop/CONTRIBUTORS.md) are retained.
Original SwiftUI code remains available under its
[MIT notice](docs/LICENSE-SWIFTUI-MIT). Third-party assets retain their respective
rights; the source license does not grant rights to redistribute user music.
