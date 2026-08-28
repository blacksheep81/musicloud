import { afterEach, describe, expect, it, vi } from 'vitest';
import { mkdtemp, writeFile, rm, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';

// OneDrive tests use fake MSAL and storage, never real accounts or OS credentials.
const { createOneDrive, graphURL, createLoopback } = require('../../../electron/oneDrive.cjs');
const directories: string[] = [];
const clientId = '11111111-2222-3333-4444-555555555555';
const safeStorage = {
    isEncryptionAvailable: () => true,
    encryptString: (text: string) => Buffer.from(Buffer.from(text).toString('base64')),
    decryptString: (data: Buffer) => Buffer.from(data.toString(), 'base64').toString(),
};
afterEach(async () => { await Promise.all(directories.splice(0).map(dir => rm(dir, { recursive: true, force: true }))); });
async function fixture(fetchImpl = vi.fn()) {
    const directory = await mkdtemp(path.join(tmpdir(), 'musicloud-onedrive-'));
    directories.push(directory);
    await writeFile(path.join(directory, 'onedrive-auth.bin'), safeStorage.encryptString(JSON.stringify({ clientId, cache: 'test-cache' })));
    const silent = vi.fn(async (_request: any) => ({ accessToken: 'test-bearer' }));
    const service = createOneDrive({
        directory, safeStorage, fetchImpl, openExternal: vi.fn(),
        makeApplication: () => ({
            getTokenCache: () => ({ deserialize() {}, serialize: () => 'test-cache', getAllAccounts: async () => [{ username: 'test@example.invalid' }] }),
            acquireTokenSilent: silent,
        }),
    });
    return { service, directory, fetchImpl, silent };
}
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });

describe('OneDrive desktop boundary', () => {
    it('rejects off-origin and out-of-version pagination', () => {
        for (const url of ['https://evil.invalid/v1.0/x', '//evil.invalid/v1.0/x', 'https://graph.microsoft.com/beta/x', 'https://user@graph.microsoft.com/v1.0/x'])
            expect(() => graphURL(url)).toThrow();
    });
    it('restores status without exposing tokens and deletes credentials on disconnect', async () => {
        const { service, directory } = await fixture();
        expect(await service.status()).toEqual({ clientId, connected: true, username: 'test@example.invalid' });
        await service.disconnect();
        expect((await service.status()).connected).toBe(false);
        await expect(readFile(path.join(directory, 'onedrive-auth.bin'))).rejects.toThrow();
    });
    it('filters audio/folders and keeps file metadata', async () => {
        const fetchImpl = vi.fn().mockResolvedValueOnce(json({ id: 'drive' })).mockResolvedValueOnce(json({ value: [
            { id: 'folder', name: 'Music', folder: {} },
            { id: 'song', name: 'Song.FLAC', file: { mimeType: 'audio/flac' }, audio: { title: 'Song', duration: 12000 }, size: 10 },
            { id: 'other', name: 'notes.txt', file: {} },
        ] }));
        const { service } = await fixture(fetchImpl);
        expect((await service.list()).items.map((item: any) => item.id)).toEqual(['folder', 'song']);
    });
    it('rejects pagination from another drive before requesting it', async () => {
        const fetchImpl = vi.fn().mockResolvedValue(json({ id: 'drive' }));
        const { service } = await fixture(fetchImpl);
        await expect(service.list({ cursor: 'https://graph.microsoft.com/v1.0/drives/other/root/children' })).rejects.toThrow('Pagination');
        expect(fetchImpl).toHaveBeenCalledTimes(1);
    });
    it('refreshes once after a 401', async () => {
        const fetchImpl = vi.fn().mockResolvedValueOnce(json({}, 401)).mockResolvedValueOnce(json({ id: 'drive' })).mockResolvedValueOnce(json({ value: [] }));
        const { service, silent } = await fixture(fetchImpl);
        await service.list();
        expect(silent.mock.calls.some((args: any[]) => args[0].forceRefresh)).toBe(true);
    });
    it('never forwards the Graph token to the download URL', async () => {
        const fetchImpl = vi.fn().mockResolvedValueOnce(json({ id: 'drive' })).mockResolvedValueOnce(json({
            name: 'song.wav', file: {}, size: 3, '@microsoft.graph.downloadUrl': 'https://files.1drv.com/test',
        })).mockResolvedValueOnce(new Response(new Uint8Array([1, 2, 3])));
        const { service } = await fixture(fetchImpl);
        expect(await service.audio({ driveId: 'drive', itemId: 'song' })).toEqual(new Uint8Array([1, 2, 3]));
        expect(fetchImpl.mock.calls[2][1].headers).toBeUndefined();
        expect(fetchImpl.mock.calls[2][1].redirect).toBe('error');
    });
    it('rejects another account, oversized files and unsafe downloads', async () => {
        const { service } = await fixture(vi.fn().mockResolvedValue(json({ id: 'other' })));
        await expect(service.audio({ driveId: 'drive', itemId: 'song' })).rejects.toThrow('another OneDrive');
        for (const item of [
            { name: 'a.flac', file: {}, size: 129 * 1024 * 1024 },
            { name: 'a.flac', file: {}, size: 1, '@microsoft.graph.downloadUrl': 'http://files.1drv.com/a' },
            { name: 'a.flac', file: {}, size: 1, '@microsoft.graph.downloadUrl': 'https://evil.invalid/a' },
        ]) {
            const { service } = await fixture(vi.fn().mockResolvedValueOnce(json({ id: 'drive' })).mockResolvedValueOnce(json(item)));
            await expect(service.audio({ driveId: 'drive', itemId: 'song' })).rejects.toThrow();
        }
    });
    it('invalidates a pending Graph response on disconnect', async () => {
        let finish!: (response: Response) => void;
        const fetchImpl = vi.fn(() => new Promise<Response>(resolve => { finish = resolve; }));
        const { service } = await fixture(fetchImpl);
        const pending = service.list();
        const rejected = expect(pending).rejects.toThrow();
        await vi.waitFor(() => expect(fetchImpl).toHaveBeenCalledTimes(1));
        await service.disconnect();
        finish(json({ id: 'drive' }));
        await rejected;
        expect((await service.status()).connected).toBe(false);
    });
    it('validates loopback state and supports cancellation', async () => {
        const loopback = createLoopback('expected');
        const result = loopback.listenForAuthCode();
        try {
            await vi.waitFor(() => expect(loopback.getRedirectUri()).toContain('localhost'));
            const callback = loopback.getRedirectUri().replace('localhost', '127.0.0.1');
            expect((await fetch(callback + '/?state=wrong&code=x')).status).toBe(400);
            await fetch(callback + '/?state=expected&code=ok');
            expect(await result).toMatchObject({ code: 'ok', state: 'expected' });
        } finally { loopback.closeServer(); }
        const cancelled = createLoopback('x');
        const pending = cancelled.listenForAuthCode();
        const rejected = expect(pending).rejects.toThrow('cancelled');
        cancelled.closeServer();
        await rejected;
    });
});
