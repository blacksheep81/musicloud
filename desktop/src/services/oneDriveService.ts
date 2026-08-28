import type { LocalSong } from '../types';
import type { OneDriveBridge, OneDriveItem, OneDriveReference, OneDriveResult } from '../types/oneDrive';
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
    const additions = items.filter(item => !item.folder).map(item => oneDriveSong(driveId, item)).filter(song => {
        if (existing.has(song.id)) return false;
        existing.add(song.id);
        return true;
    });
    if (additions.length) await saveLocalSongs(additions);
    return additions.length;
}

// Finish scanning before writing the library, so cancellation or a failed page
// never silently imports only part of a selected folder.
export async function collectOneDriveSongs(
    bridge: Pick<OneDriveBridge, 'list'>, driveId: string, selected: OneDriveItem[],
    options: { signal?: AbortSignal; onProgress?: (count: number) => void } = {},
): Promise<OneDriveItem[]> {
    const songs = new Map<string, OneDriveItem>();
    const visited = new Set<string>();
    const pending = [...selected];
    const checkCancelled = () => options.signal?.throwIfAborted();
    const collect = (item: OneDriveItem) => {
        if (item.folder) pending.push(item);
        else songs.set(item.id, item);
    };
    while (pending.length) {
        checkCancelled();
        const item = pending.pop()!;
        if (!item.folder) { songs.set(item.id, item); continue; }
        if (visited.has(item.id)) continue;
        visited.add(item.id);
        const cursors = new Set<string>();
        let cursor: string | undefined;
        do {
            checkCancelled();
            const page = await unwrapOneDrive(bridge.list({ folderId: item.id, cursor }));
            checkCancelled();
            if (page.driveId !== driveId) throw new Error('OneDrive account changed. Please retry.');
            page.items.forEach(collect);
            options.onProgress?.(songs.size);
            cursor = page.cursor || undefined;
            if (cursor && cursors.has(cursor)) throw new Error('OneDrive returned a repeated page. Please retry.');
            if (cursor) cursors.add(cursor);
        } while (cursor);
    }
    checkCancelled();
    return [...songs.values()];
}

export async function readOneDriveAudio(reference: OneDriveReference): Promise<ArrayBuffer> {
    const bridge = window.electron?.oneDrive;
    if (!bridge) throw new Error('OneDrive playback requires the Musicloud desktop app.');
    const bytes = await unwrapOneDrive(bridge.audio(reference));
    return new Uint8Array(bytes).buffer;
}
