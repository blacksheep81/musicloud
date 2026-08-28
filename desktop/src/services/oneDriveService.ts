import type { LocalSong } from '../types';
import type { OneDriveItem, OneDriveReference, OneDriveResult } from '../types/oneDrive';
import { saveLocalSongs, getLocalSongs } from './db';

// OneDrive files project into the existing library while retaining stable cloud identity.
export async function unwrapOneDrive<T>(promise: Promise<OneDriveResult<T>>): Promise<T> {
    const result = await promise;
    if (!result.ok) throw new Error(result.error);
    return result.value;
}

export function oneDriveSong(driveId: string, item: OneDriveItem): LocalSong {
    const identity = 'onedrive:' + encodeURIComponent(driveId) + ':' + encodeURIComponent(item.id);
    return {
        id: identity, oneDrive: { driveId, itemId: item.id }, fileName: item.name,
        filePath: identity, folderName: 'OneDrive / ' + driveId,
        duration: item.duration, fileSize: item.size, mimeType: item.mimeType, addedAt: Date.now(),
        title: item.title, titleOrigin: 'import',
        importedMetadata: {
            title: item.title, titleSource: 'filename', artistNames: item.artist ? [item.artist] : [],
            albumName: item.album,
        },
    };
}

export async function importOneDriveSongs(driveId: string, items: OneDriveItem[]): Promise<number> {
    const existing = new Set((await getLocalSongs()).map(song => song.id));
    const additions = items.filter(item => !item.folder).map(item => oneDriveSong(driveId, item)).filter(song => !existing.has(song.id));
    if (additions.length) await saveLocalSongs(additions);
    return additions.length;
}

export async function readOneDriveAudio(reference: OneDriveReference): Promise<ArrayBuffer> {
    const bridge = window.electron?.oneDrive;
    if (!bridge) throw new Error('OneDrive playback requires the Musicloud desktop app.');
    const bytes = await unwrapOneDrive(bridge.audio(reference));
    return new Uint8Array(bytes).buffer;
}
