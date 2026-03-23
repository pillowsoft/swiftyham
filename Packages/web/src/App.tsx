import { useEffect, useState } from 'react';
import { useSnapshot } from 'valtio';
import { appStore, setTheme } from '@/stores/app';
import { loadDemoData, connectDatabase } from '@/stores/logbook';
import { useDatabase } from '@/hooks/useDatabase';
import { useBridge } from '@/hooks/useBridge';
import { Sidebar } from '@/components/layout/Sidebar';
import { StatusBar } from '@/components/layout/StatusBar';
import { Inspector } from '@/components/layout/Inspector';
import { LogbookTable } from '@/components/logbook/LogbookTable';
import { QSOEntryForm } from '@/components/logbook/QSOEntryForm';
import { PropagationDash } from '@/components/propagation/PropagationDash';
import { AwardsDashboard } from '@/components/awards/AwardsDashboard';
import { ToolsPanel } from '@/components/tools/ToolsPanel';
import { SatelliteTracker } from '@/components/satellite/SatelliteTracker';
import { ContestPanel } from '@/components/contest/ContestPanel';
import { DXClusterPanel } from '@/components/cluster/DXClusterPanel';
import { FT8Panel } from '@/components/ft8/FT8Panel';
import { AIAssistantChat } from '@/components/ai/AIAssistantChat';
import { ImportButton, ExportButton } from '@/components/logbook/ADIFImportExport';
import { GreatCircleMap } from '@/components/maps/GreatCircleMap';
import { CWTraining } from '@/components/cw/CWTraining';
import { AntennaCalc } from '@/components/maps/AntennaCalc';
import { SOTAPOTAPanel } from '@/components/maps/SOTAPOTAPanel';
import { RepeaterPanel } from '@/components/maps/RepeaterPanel';
import { EmCommPanel } from '@/components/maps/EmCommPanel';
import { BridgeGate } from '@/components/shared/BridgeGate';
import { SettingsDialog } from '@/components/settings/SettingsDialog';
import { OnboardingWizard } from '@/components/onboarding/OnboardingWizard';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import { Settings, PanelRightClose, PanelRight, Sun, Moon, Eye, Plus } from 'lucide-react';

export function App() {
  const snap = useSnapshot(appStore);
  const [showNewQSO, setShowNewQSO] = useState(false);

  const dbCtx = useDatabase();
  useBridge(); // Auto-detect bridge on localhost:8412

  // Initialize theme on mount + load fallback demo data
  useEffect(() => {
    document.documentElement.className = appStore.theme;
    loadDemoData(); // Loads in-memory fallback immediately
  }, []);

  // When database is ready, reconnect and reload from DB
  useEffect(() => {
    if (dbCtx?.isReady) {
      connectDatabase(dbCtx.repo, dbCtx.save);
      loadDemoData(); // Now loads from DB
    }
  }, [dbCtx?.isReady]);

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
          <aside className="w-[280px] min-w-[250px] border-l border-border bg-card overflow-hidden">
            <Inspector />
          </aside>
        )}
      </div>

      <StatusBar />

      {/* Modals */}
      <QSOEntryForm open={showNewQSO} onOpenChange={setShowNewQSO} />
      {snap.showSettings && <SettingsDialog onClose={() => { appStore.showSettings = false; }} />}
      <OnboardingWizard
        open={!snap.hasCompletedOnboarding}
        onComplete={() => {}}
      />
    </div>
  );
}

function Toolbar({ onNewQSO }: { onNewQSO: () => void }) {
  const snap = useSnapshot(appStore);

  return (
    <div className="flex items-center gap-3 px-4 py-2 bg-card border-b border-border">
      {/* Callsign */}
      <span className="text-sm font-bold font-mono text-primary">
        {snap.operatorCallsign || 'N0CALL'}
      </span>

      {/* New QSO button */}
      <Button onClick={onNewQSO} title="New QSO (⌘N)">
        <Plus size={16} /> Log QSO
      </Button>

      <ImportButton />
      <ExportButton />

      <div className="flex-1" />

      {/* Theme toggle */}
      <div className="flex items-center gap-1">
        <Button variant={snap.theme === 'light' ? 'default' : 'ghost'} size="icon" onClick={() => setTheme('light')} title="Light">
          <Sun size={16} />
        </Button>
        <Button variant={snap.theme === 'dark' ? 'default' : 'ghost'} size="icon" onClick={() => setTheme('dark')} title="Dark">
          <Moon size={16} />
        </Button>
        <Button variant={snap.theme === 'night' ? 'default' : 'ghost'} size="icon" onClick={() => setTheme('night')} title="Night">
          <Eye size={16} />
        </Button>
      </div>

      <Separator orientation="vertical" className="h-4" />

      {/* Inspector toggle */}
      <Button variant="ghost" size="icon" onClick={() => { appStore.showInspector = !appStore.showInspector; }} title={snap.showInspector ? 'Hide Inspector' : 'Show Inspector'}>
        {snap.showInspector ? <PanelRightClose size={16} /> : <PanelRight size={16} />}
      </Button>

      {/* Settings */}
      <Button variant="ghost" size="icon" onClick={() => { appStore.showSettings = !appStore.showSettings; }} title="Settings">
        <Settings size={16} />
      </Button>
    </div>
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
    case 'contest':
      return <ContestPanel />;
    case 'satellite':
      return <SatelliteTracker />;
    case 'aiAssistant':
      return <AIAssistantChat />;
    case 'tools':
      return <ToolsPanel />;
    case 'greatCircleMap':
      return <GreatCircleMap />;
    case 'cwTraining':
      return <CWTraining />;
    case 'sotaPota':
      return <SOTAPOTAPanel />;
    case 'repeaters':
      return <RepeaterPanel />;
    case 'globe':
      return <EmCommPanel />; // Globe will use Three.js — showing EmComm for now
    case 'dxCluster':
      return <DXClusterPanel />;
    case 'ft8':
      return <FT8Panel />;
    case 'audioSpectrum':
      return (
        <BridgeGate feature="Audio Spectrum" description="Real-time FFT spectrum analyzer and waterfall display. Requires audio input via the bridge.">
          <div />
        </BridgeGate>
      );
    case 'bandMap':
      return (
        <BridgeGate feature="Band Map" description="Live frequency-axis display of DX spots with rig cursor. Requires rig connection via the bridge.">
          <div />
        </BridgeGate>
      );
    default:
      return (
        <div className="flex flex-col items-center justify-center flex-1" className="text-muted-foreground">
          <p className="text-lg font-medium capitalize" className="text-muted-foreground">
            {section.replace(/([A-Z])/g, ' $1').trim()}
          </p>
          <p className="text-sm mt-1">Coming soon</p>
        </div>
      );
  }
}
