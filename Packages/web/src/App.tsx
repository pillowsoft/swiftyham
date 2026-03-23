import { useEffect, useState } from 'react';
import { useSnapshot } from 'valtio';
import { appStore, setTheme } from '@/stores/app';
import { logbookStore, loadDemoData } from '@/stores/logbook';
import { Sidebar } from '@/components/layout/Sidebar';
import { StatusBar } from '@/components/layout/StatusBar';
import { Inspector } from '@/components/layout/Inspector';
import { LogbookTable } from '@/components/logbook/LogbookTable';
import { QSOEntryForm } from '@/components/logbook/QSOEntryForm';
import { PropagationDash } from '@/components/propagation/PropagationDash';
import { AwardsDashboard } from '@/components/awards/AwardsDashboard';
import { ToolsPanel } from '@/components/tools/ToolsPanel';
import { SettingsDialog } from '@/components/settings/SettingsDialog';
import { Settings, PanelRightClose, PanelRight, Sun, Moon, Eye, Plus } from 'lucide-react';

export function App() {
  const snap = useSnapshot(appStore);
  const [showNewQSO, setShowNewQSO] = useState(false);

  // Initialize theme on mount
  useEffect(() => {
    document.documentElement.className = appStore.theme;
    loadDemoData();
  }, []);

  // Keyboard shortcut: Cmd+N for new QSO
  useEffect(() => {
    function handleKey(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === 'n') {
        e.preventDefault();
        setShowNewQSO(true);
      }
      if (e.key === 'Escape') {
        setShowNewQSO(false);
        appStore.showSettings = false;
      }
    }
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, []);

  return (
    <div className="flex flex-col h-screen">
      {/* Toolbar */}
      <Toolbar onNewQSO={() => setShowNewQSO(true)} />

      {/* Main layout */}
      <div className="flex flex-1 overflow-hidden">
        <Sidebar />

        <main className="flex-1 flex flex-col overflow-hidden">
          <ContentView section={snap.selectedSection} />
        </main>

        {snap.showInspector && (
          <aside
            className="border-l overflow-hidden"
            style={{ width: 280, minWidth: 250, background: 'var(--bg-surface)', borderColor: 'var(--border)' }}
          >
            <Inspector />
          </aside>
        )}
      </div>

      <StatusBar />

      {/* Modals */}
      {showNewQSO && <QSOEntryForm onClose={() => setShowNewQSO(false)} />}
      {snap.showSettings && <SettingsDialog onClose={() => { appStore.showSettings = false; }} />}
    </div>
  );
}

function Toolbar({ onNewQSO }: { onNewQSO: () => void }) {
  const snap = useSnapshot(appStore);

  return (
    <div
      className="flex items-center gap-3"
      style={{
        height: 36,
        paddingLeft: 12,
        paddingRight: 12,
        background: 'var(--bg-surface)',
        borderBottom: '1px solid var(--border)',
      }}
    >
      {/* Callsign */}
      <span
        className="text-sm font-bold"
        style={{ fontFamily: 'var(--font-mono)', color: 'var(--accent)' }}
      >
        {snap.operatorCallsign || 'N0CALL'}
      </span>

      {/* New QSO button */}
      <button
        onClick={onNewQSO}
        className="flex items-center gap-1 px-2 py-1 rounded text-xs font-medium cursor-pointer"
        style={{ background: 'var(--accent)', color: 'white' }}
        title="New QSO (⌘N)"
      >
        <Plus size={12} /> Log QSO
      </button>

      <div className="flex-1" />

      {/* Theme toggle */}
      <div className="flex items-center gap-1">
        <ToolbarButton
          icon={<Sun size={14} />}
          active={snap.theme === 'light'}
          onClick={() => setTheme('light')}
          title="Light"
        />
        <ToolbarButton
          icon={<Moon size={14} />}
          active={snap.theme === 'dark'}
          onClick={() => setTheme('dark')}
          title="Dark"
        />
        <ToolbarButton
          icon={<Eye size={14} />}
          active={snap.theme === 'night'}
          onClick={() => setTheme('night')}
          title="Night"
        />
      </div>

      <div style={{ width: 1, height: 16, background: 'var(--border)' }} />

      {/* Inspector toggle */}
      <ToolbarButton
        icon={snap.showInspector ? <PanelRightClose size={14} /> : <PanelRight size={14} />}
        onClick={() => { appStore.showInspector = !appStore.showInspector; }}
        title={snap.showInspector ? 'Hide Inspector' : 'Show Inspector'}
      />

      {/* Settings */}
      <ToolbarButton
        icon={<Settings size={14} />}
        onClick={() => { appStore.showSettings = !appStore.showSettings; }}
        title="Settings"
      />
    </div>
  );
}

function ToolbarButton({ icon, onClick, title, active }: {
  icon: React.ReactNode;
  onClick: () => void;
  title: string;
  active?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      title={title}
      className="p-1 rounded cursor-pointer transition-colors"
      style={{
        color: active ? 'var(--accent)' : 'var(--text-secondary)',
        background: active ? 'var(--accent-dim)' : undefined,
      }}
      onMouseEnter={(e) => {
        if (!active) (e.currentTarget as HTMLElement).style.background = 'var(--bg-tertiary)';
      }}
      onMouseLeave={(e) => {
        if (!active) (e.currentTarget as HTMLElement).style.background = '';
      }}
    >
      {icon}
    </button>
  );
}

function ContentView({ section }: { section: string }) {
  switch (section) {
    case 'logbook':
      return <LogbookTable />;
    case 'propagation':
      return <PropagationDash />;
    case 'awards':
      return <AwardsDashboard />;
    case 'tools':
      return <ToolsPanel />;
    default:
      return (
        <div className="flex flex-col items-center justify-center flex-1" style={{ color: 'var(--text-muted)' }}>
          <p className="text-lg font-medium capitalize" style={{ color: 'var(--text-secondary)' }}>
            {section.replace(/([A-Z])/g, ' $1').trim()}
          </p>
          <p className="text-sm mt-1">Coming soon</p>
        </div>
      );
  }
}
