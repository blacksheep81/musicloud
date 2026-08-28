const crypto = require('node:crypto');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { PublicClientApplication, AuthError } = require('@azure/msal-node');

// Desktop-only OneDrive OAuth and read-only Graph access. Secrets never cross IPC.
const GRAPH = 'https://graph.microsoft.com/v1.0/';
const SCOPES = ['Files.Read'];
const MAX_AUDIO_BYTES = 128 * 1024 * 1024;
const audioExtension = /\.(flac|wav|mp3|m4a|aac|aiff?|ogg|opus)$/i;
const id = value => {
    if (typeof value !== 'string' || !value || value.length > 512) throw new Error('Invalid OneDrive item ID.');
    return encodeURIComponent(value);
};

function graphURL(value) {
    const url = new URL(value, GRAPH);
    if (url.origin !== 'https://graph.microsoft.com' || !url.pathname.startsWith('/v1.0/') || url.username || url.password || url.hash)
        throw new Error('Untrusted OneDrive pagination URL.');
    return url.href;
}

function createLoopback(state) {
    let server, rejectPending, redirectUri, closed = false;
    return {
        listenForAuthCode() {
            return new Promise((resolve, reject) => {
                rejectPending = reject;
                server = http.createServer((req, res) => {
                    const url = new URL(req.url, 'http://localhost');
                    if (req.method !== 'GET' || url.pathname !== '/' || url.searchParams.getAll('state').length !== 1 || url.searchParams.get('state') !== state) {
                        res.writeHead(400).end('Invalid authorization response.');
                        return;
                    }
                    if (url.searchParams.getAll('code').length > 1 || url.searchParams.getAll('error').length > 1) {
                        res.writeHead(400).end('Invalid authorization response.');
                        return;
                    }
                    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
                    res.end('Authorization received. Return to Musicloud.');
                    resolve(Object.fromEntries(url.searchParams));
                });
                server.on('error', reject);
                server.listen(0, '127.0.0.1', () => {
                    if (closed) { server.close(); return; }
                    redirectUri = 'http://localhost:' + server.address().port;
                });
            });
        },
        getRedirectUri() {
            if (!redirectUri) throw new AuthError('no_loopback_server_exists');
            return redirectUri;
        },
        closeServer() {
            closed = true;
            rejectPending?.(new Error('OneDrive login cancelled or timed out.'));
            server?.close();
            server?.closeAllConnections();
        },
    };
}

function createOneDrive({ directory, safeStorage, openExternal, fetchImpl = fetch, makeApplication = config => new PublicClientApplication(config) }) {
    const cacheFile = path.join(directory, 'onedrive-auth.bin');
    let client, clientId = '', generation = 0, loginLoopback, loading;
    let writes = Promise.resolve();
    const controllers = new Set();
    function requireEncryption() {
        if (!safeStorage.isEncryptionAvailable() || safeStorage.getSelectedStorageBackend?.() === 'basic_text')
            throw new Error('Secure OS credential storage is unavailable.');
    }
    function application(value, cache = '') {
        const version = generation;
        const app = makeApplication({
            auth: { clientId: value, authority: 'https://login.microsoftonline.com/common' },
            system: { loggerOptions: { loggerCallback: () => {}, piiLoggingEnabled: false } },
        });
        if (cache) app.getTokenCache().deserialize(cache);
        return { app, version, clientId: value };
    }
    async function load() {
        if (!loading) loading = (async () => {
            try {
                const encrypted = await fs.readFile(cacheFile);
                requireEncryption();
                const saved = JSON.parse(safeStorage.decryptString(encrypted));
                if (!/^[0-9a-f-]{36}$/i.test(saved.clientId)) throw new Error('Invalid saved Client ID.');
                clientId = saved.clientId;
                client = application(clientId, saved.cache);
            } catch (error) {
                if (error.code !== 'ENOENT') throw new Error('Cannot unlock OneDrive credentials. Disconnect and sign in again.');
            }
        })();
        return loading;
    }
    async function writeCache(current) {
        if (current.version !== generation) throw new Error('OneDrive connection changed.');
        requireEncryption();
        const data = safeStorage.encryptString(JSON.stringify({ clientId: current.clientId, cache: current.app.getTokenCache().serialize() }));
        await fs.mkdir(directory, { recursive: true });
        const temporary = cacheFile + '.' + crypto.randomUUID();
        try {
            await fs.writeFile(temporary, data, { mode: 0o600 });
            if (current.version !== generation) throw new Error('OneDrive connection changed.');
            await fs.rename(temporary, cacheFile);
        } finally { await fs.rm(temporary, { force: true }); }
    }
    function persist(current) {
        const next = writes.catch(() => {}).then(() => writeCache(current));
        writes = next;
        return next;
    }
    async function status() {
        await load();
        const account = client && (await client.app.getTokenCache().getAllAccounts())[0];
        return { clientId, connected: Boolean(account), username: account?.username || '' };
    }
    async function login(value) {
        if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value || '')) throw new Error('Enter an Application (client) ID, not an email address.');
        if (loginLoopback) throw new Error('A OneDrive login is already in progress.');
        await load();
        requireEncryption();
        const current = application(value);
        const state = crypto.randomBytes(32).toString('hex');
        const loopback = createLoopback(state);
        loginLoopback = loopback;
        const timer = setTimeout(() => loopback.closeServer(), 180000);
        try {
            await current.app.acquireTokenInteractive({
                scopes: SCOPES, prompt: 'select_account', state, loopbackClient: loopback,
                openBrowser: async url => {
                    if (new URL(url).origin !== 'https://login.microsoftonline.com') throw new Error('Unexpected authorization URL.');
                    await openExternal(url);
                },
            });
            if (current.version !== generation) throw new Error('OneDrive login cancelled.');
            await persist(current);
            if (current.version !== generation) throw new Error('OneDrive login cancelled.');
            client = current;
            clientId = value;
            return status();
        } finally {
            clearTimeout(timer);
            loopback.closeServer();
            if (loginLoopback === loopback) loginLoopback = null;
        }
    }
    async function token(forceRefresh = false) {
        await load();
        const current = client;
        const account = current && (await current.app.getTokenCache().getAllAccounts())[0];
        if (!account) throw new Error('Sign in to OneDrive first.');
        const result = await current.app.acquireTokenSilent({ account, scopes: SCOPES, forceRefresh });
        await persist(current);
        return result.accessToken;
    }
    async function request(url, options = {}) {
        const controller = new AbortController();
        controllers.add(controller);
        const timer = setTimeout(() => controller.abort(), 120000);
        try { return await fetchImpl(url, { ...options, signal: controller.signal, redirect: 'error' }); }
        finally { clearTimeout(timer); controllers.delete(controller); }
    }
    async function graph(route) {
        const url = graphURL(route);
        const version = generation;
        let response = await request(url, { headers: { Authorization: 'Bearer ' + await token() } });
        if (response.status === 401) response = await request(url, { headers: { Authorization: 'Bearer ' + await token(true) } });
        if (!response.ok) throw new Error('OneDrive request failed (' + response.status + '). Please retry or sign in again.');
        const data = await response.json();
        if (version !== generation) throw new Error('OneDrive connection changed.');
        return data;
    }
    async function list({ folderId, cursor } = {}) {
        const drive = await graph('me/drive?$select=id,name');
        const prefix = 'drives/' + id(drive.id) + '/';
        const route = prefix + (folderId ? 'items/' + id(folderId) : 'root') + '/children';
        if (cursor && new URL(graphURL(cursor)).pathname !== new URL(GRAPH + route).pathname)
            throw new Error('Pagination does not belong to this OneDrive folder.');
        const data = await graph(cursor || route + '?$top=100&$select=id,name,size,folder,file,audio,parentReference');
        return {
            driveId: drive.id,
            items: (data.value || []).filter(item => item.folder || (item.file && audioExtension.test(item.name))).map(item => ({
                id: item.id, name: item.name, size: item.size || 0, folder: Boolean(item.folder),
                mimeType: item.file?.mimeType || 'application/octet-stream',
                title: item.audio?.title || item.name.replace(/\.[^.]+$/, ''),
                artist: item.audio?.artist || '', album: item.audio?.album || '', duration: item.audio?.duration || 0,
            })),
            cursor: data['@odata.nextLink'] ? graphURL(data['@odata.nextLink']) : null,
        };
    }
    async function audio(reference) {
        const version = generation;
        const drive = await graph('me/drive?$select=id');
        if (drive.id !== reference.driveId) throw new Error('This track belongs to another OneDrive. Sign in to its account.');
        const item = await graph('drives/' + id(drive.id) + '/items/' + id(reference.itemId));
        if (!item.file || !audioExtension.test(item.name)) throw new Error('Not a supported audio file.');
        if (item.size > MAX_AUDIO_BYTES) throw new Error('This preview supports audio files up to 128 MB.');
        const url = new URL(item['@microsoft.graph.downloadUrl']);
        const allowed = ['1drv.com', 'onedrive.com', 'live.com', 'sharepoint.com', 'sharepoint.cn'];
        if (url.protocol !== 'https:' || url.username || url.password || url.port || !allowed.some(host => url.hostname === host || url.hostname.endsWith('.' + host)))
            throw new Error('Untrusted OneDrive download host.');
        const controller = new AbortController();
        controllers.add(controller);
        const timer = setTimeout(() => controller.abort(), 120000);
        try {
            // Never send the Graph bearer token to the pre-authorized download host.
            const response = await fetchImpl(url.href, { signal: controller.signal, redirect: 'error' });
            if (!response.ok || !response.body) throw new Error('OneDrive audio download failed.');
            let size = 0;
            const parts = [];
            for await (const chunk of response.body) {
                size += chunk.length;
                if (size > MAX_AUDIO_BYTES) { controller.abort(); throw new Error('Audio exceeds the 128 MB preview limit.'); }
                parts.push(Buffer.from(chunk));
            }
            if (version !== generation) throw new Error('OneDrive connection changed.');
            return new Uint8Array(Buffer.concat(parts));
        } finally { clearTimeout(timer); controllers.delete(controller); }
    }
    async function disconnect() {
        generation++;
        loginLoopback?.closeServer();
        for (const controller of controllers) controller.abort();
        // Await initial load so it cannot resurrect credentials after logout.
        await loading?.catch(() => {});
        await writes.catch(() => {});
        client = null; clientId = ''; loading = Promise.resolve();
        await fs.rm(cacheFile, { force: true });
        return { connected: false, clientId: '', username: '' };
    }
    return { status, login, list, audio, disconnect, cancel: async () => {
        if (!loginLoopback) return;
        generation++;
        if (client) client.version = generation;
        loginLoopback.closeServer();
        await writes.catch(() => {});
        if (client) await persist(client);
        else await fs.rm(cacheFile, { force: true });
    } };
}
module.exports = { createOneDrive, graphURL, createLoopback };
