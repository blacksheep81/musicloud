// Serializable IPC contracts. OAuth tokens and download URLs stay in the main process.
export type OneDriveReference = { driveId: string; itemId: string };
export type OneDriveStatus = { clientId: string; connected: boolean; username: string };
export type OneDriveItem = {
    id: string; name: string; size: number; folder: boolean;
    mimeType: string; title: string; artist: string; album: string; duration: number;
};
export type OneDrivePage = { driveId: string; items: OneDriveItem[]; cursor: string | null };
export type OneDriveResult<T> = { ok: true; value: T } | { ok: false; error: string };
export type OneDriveBridge = {
    status(): Promise<OneDriveResult<OneDriveStatus>>;
    login(clientId: string): Promise<OneDriveResult<OneDriveStatus>>;
    list(request: { folderId?: string; cursor?: string }): Promise<OneDriveResult<OneDrivePage>>;
    audio(reference: OneDriveReference): Promise<OneDriveResult<Uint8Array>>;
    disconnect(): Promise<OneDriveResult<OneDriveStatus>>;
    cancel(): Promise<OneDriveResult<void>>;
};
