# OneDrive Desktop Preview

## Register a Microsoft Application

1. In Microsoft Entra, open App registrations and register an application.
   Choose the supported account types you need; for both personal and work
   OneDrive accounts, choose organizational directories and personal Microsoft accounts.
2. Under Authentication, add **Mobile and desktop applications**, with redirect
   URI **http://localhost**. MSAL uses a random loopback port.
3. Add Microsoft Graph delegated **Files.Read** permission. Organization policy
   may require an administrator's consent.
4. Copy **Application (client) ID**, the UUID, not an email address or tenant ID.
   Do not create or enter a client secret for this public desktop application.
5. In Musicloud desktop, open Cloud > OneDrive, enter that ID and select
   Sign in with Microsoft. Complete authentication in your system browser.

References:
- [Microsoft desktop configuration](https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-configuration)
- [Redirect URI rules](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url)
- [Graph download behavior](https://learn.microsoft.com/en-us/graph/api/driveitem-get-content?view=graph-rest-1.0)

## Import and Play

Browse folders, select audio files and choose Add to library. They appear under
Folder, grouped as OneDrive / drive ID. Import stores metadata and stable drive
and item IDs, not audio or expiring download links. Duplicate imports are skipped.

Playback downloads the complete file before handing it to Folia's existing audio
player. The preview limit is **128 MB per file**, with a two-minute download
timeout. This is not streaming or an offline cache. Once loaded, normal seeking
uses the downloaded blob. Changing tracks discards stale playback results.

Graph-provided title, artist, album and duration are used where available.
Cloud sidecar lyrics, cloud artwork fetching, shared-drive/SharePoint selection,
rescan/deletion synchronization and offline caching are not implemented.
Existing Folia lyric rendering/matching remains in place; missing cloud tags may
reduce automatic lyric matching quality.

## Security and Limitations

- Desktop only; the web preview intentionally cannot authorize or read OneDrive.
- MSAL handles PKCE and refresh. The loopback listener validates state and closes
  on completion, cancellation or after three minutes.
- The serialized token cache is encrypted with Electron safeStorage and written
  with owner-only permissions under the isolated Musicloud profile.
- The app refuses unavailable encryption and Linux's plaintext basic_text backend.
- Tokens and pre-authorized download links are not exposed to the renderer.
- Graph pagination is restricted to the requested folder. Downloads require an
  allowed HTTPS OneDrive/SharePoint hostname, reject redirects, and receive no
  Graph bearer header. Some unusual tenant download hosts may therefore fail.
- Disconnect removes saved local credentials and cancels outstanding network
  work; it does not revoke Microsoft consent, remove imported library records,
  or stop an already downloaded track. Revoke app consent in Microsoft account
  settings when needed.
- Existing NAS credentials still follow Folia's inherited Navidrome storage;
  the encrypted credential implementation described here is OneDrive-specific.

## Validation

Typecheck and 30 focused tests passed (11 new OneDrive tests plus 19 existing
navigation/command tests). Tests use synthetic accounts, MSAL/storage mocks,
fake Graph responses and a real loopback HTTP listener.
The actual Electron login configuration page and initial status IPC were checked.
Real Microsoft authorization, token refresh against Microsoft, cloud-file audio
decode/playback and large-file performance remain unverified until an account
and registered Client ID are supplied.
