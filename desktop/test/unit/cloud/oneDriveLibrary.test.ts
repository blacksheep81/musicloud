import { beforeEach, describe, expect, it, vi } from 'vitest';
import { collectOneDriveSongs, oneDriveSong, importOneDriveSongs } from '../../../src/services/oneDriveService';
import type { OneDriveBridge, OneDriveItem } from '../../../src/types/oneDrive';
import { getLocalSongs, saveLocalSongs } from '../../../src/services/db';

// Stable cloud references survive persistence without embedding expiring download URLs.
vi.mock('../../../src/services/db', () => ({ getLocalSongs: vi.fn(async () => []), saveLocalSongs: vi.fn(async () => {}) }));
const item = { id: 'item', name: 'song.flac', folder: false, size: 20, mimeType: 'audio/flac', title: 'Song', artist: 'Artist', album: 'Album', duration: 5000 };
describe('OneDrive library projection', () => {
    beforeEach(() => { vi.clearAllMocks(); vi.mocked(getLocalSongs).mockResolvedValue([]); });
    it('uses drive and item identity, independent of the filename', () => {
        const song = oneDriveSong('drive', item);
        expect(song.id).toBe(oneDriveSong('drive', { ...item, name: 'renamed.flac' }).id);
        expect(song.id).not.toBe(oneDriveSong('another', item).id);
        expect(JSON.parse(JSON.stringify(song)).oneDrive).toEqual({ driveId: 'drive', itemId: 'item' });
        expect(song.importedMetadata.artistNames).toEqual(['Artist']);
    });
    it('does not import folders or duplicate songs', async () => {
        vi.mocked(getLocalSongs).mockResolvedValue([oneDriveSong('drive', item)]);
        expect(await importOneDriveSongs('drive', [item, { ...item, id: 'folder', folder: true }])).toBe(0);
        expect(saveLocalSongs).not.toHaveBeenCalled();
    });
    it('deduplicates within a batch', async () => {
        expect(await importOneDriveSongs('drive', [item, item])).toBe(1);
        expect(vi.mocked(saveLocalSongs).mock.calls[0][0]).toHaveLength(1);
    });
});

describe('OneDrive folder collection', () => {
    const folder = (id: string): OneDriveItem => ({ ...item, id, name: id, folder: true });
    const page = (items: OneDriveItem[], cursor: string | null = null, driveId = 'drive') => ({ ok: true as const, value: { driveId, items, cursor } });
    it('scans nested folders and every page, deduplicating files and overlapping folders', async () => {
        const list = vi.fn<OneDriveBridge['list']>(async ({ folderId, cursor }) => {
            if (folderId === 'parent') return cursor
                ? page([{ ...item, id: 'wav', name: 'song.wav' }, folder('child')])
                : page([item, folder('child')], 'next');
            return page([item, folder('parent')]);
        });
        const result = await collectOneDriveSongs({ list }, 'drive', [folder('parent'), folder('child'), item]);
        expect(result.map(song => song.name).sort()).toEqual(['song.flac', 'song.wav']);
        expect(list).toHaveBeenCalledTimes(3);
        expect(list).toHaveBeenCalledWith({ folderId: 'parent', cursor: 'next' });
    });
    it('stops after cancellation during a request', async () => {
        const controller = new AbortController();
        const list = vi.fn<OneDriveBridge['list']>(async () => { controller.abort(); return page([folder('child')], 'next'); });
        await expect(collectOneDriveSongs({ list }, 'drive', [folder('parent')], { signal: controller.signal })).rejects.toThrow();
        expect(list).toHaveBeenCalledTimes(1);
    });
    it('rejects errors and changed accounts instead of returning partial results', async () => {
        const list = vi.fn<OneDriveBridge['list']>().mockResolvedValueOnce(page([item], 'next')).mockResolvedValueOnce({ ok: false, error: 'Offline' });
        await expect(collectOneDriveSongs({ list }, 'drive', [folder('parent')])).rejects.toThrow('Offline');
        list.mockResolvedValue(page([item], null, 'other-drive'));
        await expect(collectOneDriveSongs({ list }, 'drive', [folder('parent')])).rejects.toThrow('account changed');
    });
    it('rejects repeated pagination cursors', async () => {
        const list = vi.fn<OneDriveBridge['list']>().mockResolvedValue(page([item], 'same'));
        await expect(collectOneDriveSongs({ list }, 'drive', [folder('parent')])).rejects.toThrow('repeated page');
        expect(list).toHaveBeenCalledTimes(2);
    });
    it('handles empty folders and pre-cancelled scans', async () => {
        const list = vi.fn<OneDriveBridge['list']>().mockResolvedValue(page([]));
        expect(await collectOneDriveSongs({ list }, 'drive', [folder('empty')])).toEqual([]);
        list.mockClear();
        const controller = new AbortController(); controller.abort();
        await expect(collectOneDriveSongs({ list }, 'drive', [item], { signal: controller.signal })).rejects.toThrow();
        expect(list).not.toHaveBeenCalled();
    });
});
