import { describe, expect, it, vi } from 'vitest';
import { oneDriveSong, importOneDriveSongs } from '../../../src/services/oneDriveService';
import { getLocalSongs, saveLocalSongs } from '../../../src/services/db';

// Stable cloud references survive persistence without embedding expiring download URLs.
vi.mock('../../../src/services/db', () => ({ getLocalSongs: vi.fn(async () => []), saveLocalSongs: vi.fn(async () => {}) }));
const item = { id: 'item', name: 'song.flac', folder: false, size: 20, mimeType: 'audio/flac', title: 'Song', artist: 'Artist', album: 'Album', duration: 5000 };
describe('OneDrive library projection', () => {
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
});
