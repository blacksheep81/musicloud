import React from 'react';
import { ArrowRight, Cloud, HardDrive, Server, Settings2 } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { getNavidromeConfig } from '../../../services/navidromeService';
import { useSettingsUiStore } from '../../../stores/useSettingsUiStore';

// Cloud source management reuses the existing NAS configuration and library.
type Props = {
    navidromeEnabled: boolean;
    onBrowseNas: () => void;
};

export default function CloudSourcesView({ navidromeEnabled, onBrowseNas }: Props) {
    const { t } = useTranslation();
    const openSettings = useSettingsUiStore(state => state.openSettings);
    // Subscribe to settings visibility so closing configuration refreshes the status.
    useSettingsUiStore(state => state.settingsModalState.isOpen);
    const configured = navidromeEnabled && Boolean(getNavidromeConfig()?.serverUrl);
    const rows = [
        { id: 'nas', name: t('cloud.nas'), protocol: 'Navidrome / Subsonic', icon: Server, color: '#8dd8bb', available: true },
        { id: 'onedrive', name: 'OneDrive', protocol: 'Microsoft', icon: Cloud, color: '#7ebfff', available: false },
        { id: 'google', name: 'Google Drive', protocol: 'Google', icon: HardDrive, color: '#e9cc7a', available: false },
        { id: 'webdav', name: 'WebDAV', protocol: t('cloud.webdav'), icon: Server, color: '#d9a9ce', available: false },
    ];
    return (
        <section aria-label={t('cloud.title')} className="w-full h-full overflow-y-auto px-5 md:px-10 pb-24" style={{ color: 'var(--text-primary)' }}>
            <div className="max-w-3xl mx-auto pt-8 md:pt-12">
                <header className="flex items-center gap-3 mb-8">
                    <Cloud size={26} aria-hidden="true" />
                    <h2 className="text-2xl font-semibold">{t('cloud.title')}</h2>
                </header>
                <div className="divide-y divide-current/10">
                    {rows.map(row => (
                        <div key={row.id} className="flex flex-wrap items-center gap-4 py-6">
                            <row.icon size={26} style={{ color: row.color }} aria-hidden="true" />
                            <div className="min-w-0 flex-1">
                                <h3 className="text-base font-semibold">{row.name}</h3>
                                <p className="text-xs mt-1 opacity-55">{row.protocol}</p>
                            </div>
                            <div className="flex items-center gap-3 ml-auto">
                                <span className="text-xs opacity-60">{t(row.available ? configured ? 'cloud.configured' : 'cloud.notConfigured' : 'cloud.pending')}</span>
                                {row.available && (
                                    <>
                                        <button
                                            onClick={() => openSettings('options', 'integration')}
                                            title={t('cloud.configure')}
                                            aria-label={t('cloud.configure')}
                                            className="p-2 rounded-md hover:bg-white/10 focus-visible:outline focus-visible:outline-2"
                                        ><Settings2 size={19} /></button>
                                        {configured && <button onClick={onBrowseNas} title={t('cloud.browse')} aria-label={t('cloud.browse')}
                                            className="p-2 rounded-md hover:bg-white/10 focus-visible:outline focus-visible:outline-2">
                                            <ArrowRight size={19} />
                                        </button>}
                                    </>
                                )}
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        </section>
    );
}
