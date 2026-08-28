# OneDrive setup (experimental)

The implementation is ready for account integration testing, not a verified
cloud-player release. No production Client ID is bundled. Google Drive is not
implemented yet.

## Register your desktop app

1. Open [Microsoft Entra app registrations](https://entra.microsoft.com/) and
   register an application, for example `musicloud development`.
2. To support both personal OneDrive and work/school accounts, choose accounts in
   any organizational directory and personal Microsoft accounts. Your tenant's
   policy may require an administrator to register or approve the app.
3. Under Authentication, add the **Mobile and desktop applications** platform
   with the custom redirect URI `musicloud://oauth` (exactly; no trailing slash).
   Do not register this as a Web or SPA redirect.
4. Add Microsoft Graph **delegated** `Files.Read` permission. The app requests
   `offline_access` during authorization for refresh tokens. Do not add write or
   application-wide permissions for this prototype. No client secret is needed.
5. Copy the Application (client) ID from Overview. This is a public identifier,
   not a password or secret.

## Connect

Build the app bundle with `bash scripts/package-app.sh` and open
`dist/Musicloud.app`. Use the app bundle for OAuth callback registration rather
than the bare `swift run` executable.

Open OneDrive from the sidebar (Command-Shift-D), enter the Client ID, and select
Connect OneDrive. The system authentication browser performs Microsoft login and
consent. A saved refresh token can reconnect without another browser prompt.
The configured Client ID is stored in local UserDefaults; tokens are in macOS
Keychain under `dev.musicloud.onedrive`, never in the repository or library JSON.

Browse folders, load additional pages, and add selected audio files to the library.
Double-clicking a folder opens it; double-clicking audio adds it. Play imported
cloud tracks from All Songs, an album, or the queue. Disconnect clears this app's
saved token and stops current cloud playback, but leaves library references and
does not revoke consent at Microsoft. Disconnect before changing the Client ID.

## Boundaries

- One connected account and its primary drive at a time; another drive's tracks
  require reconnecting the matching account.
- HTTPS Microsoft Graph requests use delegated read-only access. Pagination URLs
  are restricted to the Graph v1.0 origin. API redirects are rejected.
- Authorization code flow uses PKCE S256 and fresh random state, with callback
  scheme/host/state checks. No passwords are collected by musicloud.
- Song identity is drive ID plus item ID. Signed download links are resolved at
  playback time and are not persisted or sent a Graph Authorization header.
- Playback uses AVPlayer directly. Cache/offline playback, expired links during
  long playback, cloud artwork, recursive folder import, shared-drive shortcuts,
  incremental sync, and automated rate-limit backoff are not implemented.
- Errors such as HTTP 429 are surfaced for retry. HTTP 401 refreshes once.
- Raw cloud audio formats, seeking and connection loss require real-account QA.
  A passing mock test does not establish streaming compatibility.
- Unsigned development builds may trigger Keychain access prompts. Signing,
  notarization and wider OAuth compatibility testing remain release requirements.

## References

- [Microsoft authorization code flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
- [Redirect URI configuration](https://learn.microsoft.com/en-us/entra/identity-platform/reply-url)
- [List drive items and permissions](https://learn.microsoft.com/en-us/graph/api/driveitem-list-children?view=graph-rest-1.0)
- [Download links](https://learn.microsoft.com/en-us/graph/api/driveitem-get-content?view=graph-rest-1.0)
