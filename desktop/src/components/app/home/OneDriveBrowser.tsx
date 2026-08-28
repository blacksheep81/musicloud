import React, { useEffect, useRef, useState } from 'react';
import { ArrowLeft, Cloud, Folder, LogOut, Music2, RefreshCw, Download, X } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import type { OneDrivePage, OneDriveStatus } from '../../../types/oneDrive';
import { importOneDriveSongs, unwrapOneDrive } from '../../../services/oneDriveService';

// Main-process authentication with a renderer-only folder browser and selection state.
export default function OneDriveBrowser({ onBack, onImported }: { onBack: () => void; onImported: () => void }) {
    const { t } = useTranslation();
    const bridge = window.electron?.oneDrive;
    const [status, setStatus] = useState<OneDriveStatus>({ clientId: '', username: '', connected: false });
    const [clientId, setClientId] = useState('');
    const [page, setPage] = useState<OneDrivePage | null>(null);
    const [folders, setFolders] = useState<Array<{ id?: string; name: string }>>([{ name: 'OneDrive' }]);
    const [selected, setSelected] = useState<Set<string>>(new Set());
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState('');
    const [notice, setNotice] = useState('');
    const revision = useRef(0);
    const iconButton = 'p-2 rounded-md hover:bg-white/10 disabled:opacity-30';
    async function run(operation: (version: number) => Promise<void>) {
        const version = ++revision.current;
        setBusy(true); setError(''); setNotice('');
        try { await operation(version); }
        catch (error) { if (version === revision.current) setError(error instanceof Error ? error.message : 'OneDrive request failed.'); }
        finally { if (version === revision.current) setBusy(false); }
    }
    async function browse(nextFolders = folders, more = false, version = revision.current) {
        if (!bridge) return;
        const result = await unwrapOneDrive(bridge.list({
            folderId: nextFolders.at(-1)?.id,
            cursor: more ? page?.cursor || undefined : undefined,
        }));
        if (version !== revision.current) return;
        setPage(previous => more && previous
            ? { ...result, items: [...previous.items, ...result.items.filter(item => !previous.items.some(old => old.id === item.id))] }
            : result);
        setFolders(nextFolders);
        if (!more) setSelected(new Set());
    }
    useEffect(() => {
        if (bridge) void run(async version => {
            const saved = await unwrapOneDrive(bridge.status());
            if (version !== revision.current) return;
            setStatus(saved); setClientId(saved.clientId);
            if (saved.connected) await browse([{ name: 'OneDrive' }], false, version);
        });
        return () => { revision.current++; void bridge?.cancel(); };
    }, [bridge]);
    return (
        <section aria-label="OneDrive" className="w-full h-full overflow-y-auto px-5 md:px-10 pb-28" style={{ color: 'var(--text-primary)' }}>
            <div className="max-w-3xl mx-auto pt-6">
                <header className="flex items-center gap-3 mb-7">
                    <button onClick={onBack} title={t('oneDrive.back', 'Back to cloud')} aria-label={t('oneDrive.back', 'Back to cloud')} className={iconButton}><ArrowLeft size={20} /></button>
                    <Cloud size={24} className="text-sky-300" /><h2 className="text-2xl font-semibold">OneDrive</h2>
                    <span className="text-xs opacity-60 ml-auto">{t('oneDrive.preview', 'Preview')}</span>
                </header>
                {!bridge ? <p role="status">{t('oneDrive.desktop', 'OneDrive requires the Musicloud desktop app.')}</p> : !status.connected ? (
                    <form onSubmit={event => {
                        event.preventDefault();
                        if (busy) return;
                        void run(async version => {
                            const result = await unwrapOneDrive(bridge.login(clientId.trim()));
                            if (version !== revision.current) return;
                            setStatus(result);
                            await browse([{ name: 'OneDrive' }], false, version);
                        });
                    }} className="max-w-lg space-y-5">
                        <label className="block text-sm">
                            Application (client) ID
                            <input value={clientId} onChange={event => setClientId(event.target.value)} disabled={busy} autoComplete="off" spellCheck={false}
                                className="block w-full mt-2 p-3 bg-black/15 border border-white/20 rounded-md font-mono text-sm" />
                        </label>
                        <div className="flex gap-3 items-center">
                            <button type="submit" disabled={busy || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(clientId.trim())}
                                className="px-4 py-2 bg-white text-black rounded-md disabled:opacity-35">
                                {t('oneDrive.signIn', 'Sign in with Microsoft')}
                            </button>
                            {busy && <button type="button" onClick={() => void bridge.cancel()} aria-label={t('oneDrive.cancel', 'Cancel login')} title={t('oneDrive.cancel', 'Cancel login')} className={iconButton}><X size={18} /></button>}
                        </div>
                        <a className="text-xs underline opacity-70 block" href="https://github.com/blacksheep81/musicloud/blob/main/desktop/docs/MUSICLOUD-ONEDRIVE.md" target="_blank" rel="noreferrer">
                            {t('oneDrive.setup', 'Microsoft app registration')}
                        </a>
                    </form>
                ) : (
                    <>
                        <div className="flex gap-2 items-center flex-wrap mb-5">
                            <span className="text-sm opacity-70 break-all mr-auto">{status.username}</span>
                            <button disabled={busy} onClick={() => void run(v => browse(folders, false, v))} className={iconButton} title={t('oneDrive.refresh', 'Refresh')} aria-label={t('oneDrive.refresh', 'Refresh')}><RefreshCw size={18} /></button>
                            <button disabled={busy} onClick={() => void run(async version => {
                                const result = await unwrapOneDrive(bridge.disconnect());
                                if (version === revision.current) { setStatus(result); setClientId(''); setPage(null); setSelected(new Set()); }
                            })} className={iconButton} title={t('oneDrive.disconnect', 'Disconnect')} aria-label={t('oneDrive.disconnect', 'Disconnect')}><LogOut size={18} /></button>
                        </div>
                        <nav aria-label={t('oneDrive.path', 'Folder path')} className="flex gap-2 flex-wrap text-sm mb-5">
                            {folders.map((folder, index) => <button key={folder.id || 'root'} disabled={busy || index === folders.length - 1}
                                onClick={() => void run(v => browse(folders.slice(0, index + 1), false, v))}
                                className="max-w-full truncate underline disabled:no-underline">{folder.name}{index < folders.length - 1 ? ' /' : ''}</button>)}
                        </nav>
                        <div className="divide-y divide-white/10" aria-busy={busy}>
                            {page?.items.map(item => <div key={item.id} className="flex items-center gap-3 py-3">
                                {item.folder ? <Folder size={20} className="shrink-0 text-sky-300" /> : <input type="checkbox" aria-label={item.name} disabled={busy}
                                    checked={selected.has(item.id)} onChange={() => setSelected(previous => { const next = new Set(previous); next.has(item.id) ? next.delete(item.id) : next.add(item.id); return next; })} />}
                                {item.folder ? <button disabled={busy} onClick={() => void run(v => browse([...folders, { id: item.id, name: item.name }], false, v))} className="min-w-0 text-left break-words">{item.name}</button>
                                    : <><Music2 size={17} className="shrink-0 opacity-50" /><span className="min-w-0 flex-1 break-words text-sm">{item.name}</span><span className="text-xs opacity-50 shrink-0">{(item.size / 1048576).toFixed(1)} MB</span></>}
                            </div>)}
                        </div>
                        {page && !page.items.length && <p className="py-8 opacity-60">{t('oneDrive.empty', 'No audio files or folders.')}</p>}
                        <div className="flex items-center gap-4 mt-6">
                            <button disabled={busy || !selected.size || !page} onClick={() => void run(async version => {
                                if (!page) return;
                                const count = await importOneDriveSongs(page.driveId, page.items.filter(item => selected.has(item.id)));
                                onImported();
                                if (version === revision.current) { setSelected(new Set()); setNotice(t('oneDrive.imported', { count, defaultValue: '{{count}} tracks added to Folder' })); }
                            })} className="flex items-center gap-2 px-4 py-2 rounded-md bg-white text-black disabled:opacity-35">
                                <Download size={16} />{t('oneDrive.import', 'Add to library')} ({selected.size})
                            </button>
                            {page?.cursor && <button disabled={busy} onClick={() => void run(v => browse(folders, true, v))} className="text-sm underline">{t('oneDrive.more', 'Load more')}</button>}
                        </div>
                    </>
                )}
                {busy && <p role="status" className="text-sm opacity-60 mt-5">{t('oneDrive.loading', 'Working…')}</p>}
                {error && <p role="alert" className="text-sm text-red-300 mt-5 break-words">{error}</p>}
                {error && bridge && !status.connected && !busy && <button
                    className="text-xs underline mt-3" onClick={() => void run(async version => {
                        const result = await unwrapOneDrive(bridge.disconnect());
                        if (version === revision.current) { setStatus(result); setClientId(''); }
                    })}>{t('oneDrive.reset', 'Clear saved connection')}</button>}
                {notice && <p role="status" className="text-sm mt-5">{notice}</p>}
            </div>
        </section>
    );
}
