import { useState } from 'react';
import { useSnapshot } from 'valtio';
import { appStore, saveProfile, type Theme, setTheme } from '@/stores/app';
import { X } from 'lucide-react';

interface Props {
  onClose: () => void;
}

type SettingsTab = 'general' | 'ai' | 'about';

export function SettingsDialog({ onClose }: Props) {
  const snap = useSnapshot(appStore);
  const [tab, setTab] = useState<SettingsTab>('general');

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center" style={{ background: 'rgba(0,0,0,0.6)' }}>
      <div
        className="rounded-lg overflow-hidden flex flex-col"
        style={{ width: 520, height: 420, background: 'var(--bg-surface)', border: '1px solid var(--border)' }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3" style={{ borderBottom: '1px solid var(--border)' }}>
          <span className="font-semibold text-sm">Settings</span>
          <button onClick={onClose} className="cursor-pointer" style={{ color: 'var(--text-muted)' }}>
            <X size={16} />
          </button>
        </div>

        <div className="flex flex-1 overflow-hidden">
          {/* Tab list */}
          <div className="w-32 py-2 flex-shrink-0" style={{ borderRight: '1px solid var(--border)', background: 'var(--bg)' }}>
            {(['general', 'ai', 'about'] as SettingsTab[]).map(t => (
              <button
                key={t}
                onClick={() => setTab(t)}
                className="w-full text-left px-3 py-1.5 text-xs capitalize cursor-pointer"
                style={{
                  background: tab === t ? 'var(--accent-dim)' : 'transparent',
                  color: tab === t ? 'var(--accent)' : 'var(--text-secondary)',
                }}
              >
                {t}
              </button>
            ))}
          </div>

          {/* Tab content */}
          <div className="flex-1 overflow-y-auto p-4">
            {tab === 'general' && <GeneralSettings />}
            {tab === 'ai' && <AISettings />}
            {tab === 'about' && <AboutSettings />}
          </div>
        </div>
      </div>
    </div>
  );
}

function GeneralSettings() {
  const snap = useSnapshot(appStore);

  return (
    <div className="flex flex-col gap-4">
      <SettingsField label="Callsign">
        <input
          className="w-full rounded px-2 py-1.5 text-sm outline-none"
          style={{ fontFamily: 'var(--font-mono)', background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)', textTransform: 'uppercase' }}
          value={snap.operatorCallsign}
          onChange={(e) => { appStore.operatorCallsign = e.target.value.toUpperCase(); }}
          onBlur={saveProfile}
          placeholder="W1AW"
        />
      </SettingsField>

      <SettingsField label="Grid Square">
        <input
          className="w-full rounded px-2 py-1.5 text-sm outline-none"
          style={{ fontFamily: 'var(--font-mono)', background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
          value={snap.gridSquare}
          onChange={(e) => { appStore.gridSquare = e.target.value; }}
          onBlur={saveProfile}
          placeholder="FN31pr"
        />
      </SettingsField>

      <SettingsField label="Name">
        <input
          className="w-full rounded px-2 py-1.5 text-sm outline-none"
          style={{ background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
          value={snap.operatorName}
          onChange={(e) => { appStore.operatorName = e.target.value; }}
          onBlur={saveProfile}
        />
      </SettingsField>

      <SettingsField label="Theme">
        <div className="flex gap-2">
          {(['dark', 'light', 'night'] as Theme[]).map(t => (
            <button
              key={t}
              onClick={() => setTheme(t)}
              className="px-3 py-1 rounded text-xs capitalize cursor-pointer"
              style={{
                background: snap.theme === t ? 'var(--accent-dim)' : 'transparent',
                color: snap.theme === t ? 'var(--accent)' : 'var(--text-secondary)',
                border: `1px solid ${snap.theme === t ? 'var(--accent)' : 'var(--border)'}`,
              }}
            >
              {t}
            </button>
          ))}
        </div>
      </SettingsField>
    </div>
  );
}

function AISettings() {
  return (
    <div className="flex flex-col gap-4">
      <p className="text-xs" style={{ color: 'var(--text-secondary)' }}>
        AI features use on-device models or cloud APIs. Configure your preferred backend and privacy settings.
      </p>
      <SettingsField label="AI Provider">
        <select
          className="w-full rounded px-2 py-1.5 text-sm outline-none cursor-pointer"
          style={{ background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
        >
          <option>Local (MLX — requires bridge)</option>
          <option>OpenRouter (Claude)</option>
          <option>Anthropic (Direct)</option>
        </select>
      </SettingsField>
      <p className="text-[10px]" style={{ color: 'var(--text-muted)' }}>
        Local AI requires the HamStation Bridge CLI running on your Mac.
      </p>
    </div>
  );
}

function AboutSettings() {
  return (
    <div className="flex flex-col gap-3">
      <div className="text-center py-4">
        <div className="text-lg font-bold" style={{ color: 'var(--accent)' }}>HamStation Pro</div>
        <div className="text-xs" style={{ color: 'var(--text-muted)' }}>Web Edition • v0.1.0</div>
      </div>
      <p className="text-xs" style={{ color: 'var(--text-secondary)' }}>
        The modern amateur radio station for the web. Log contacts, track DX, monitor propagation, decode digital modes, and more.
      </p>
      <p className="text-[10px]" style={{ color: 'var(--text-muted)' }}>
        MIT License • Built with React, Valtio, and ShadCN/ui
      </p>
    </div>
  );
}

function SettingsField({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <label className="text-[10px] uppercase tracking-wider mb-1 block" style={{ color: 'var(--text-muted)' }}>
        {label}
      </label>
      {children}
    </div>
  );
}
