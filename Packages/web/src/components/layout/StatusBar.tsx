import { useSnapshot } from 'valtio';
import { appStore } from '@/stores/app';
import { logbookStore } from '@/stores/logbook';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';

export function StatusBar() {
  const app = useSnapshot(appStore);
  const logbook = useSnapshot(logbookStore);

  return (
    <div className="flex items-center gap-4 px-5 py-2 border-t border-border bg-card text-xs font-mono text-muted-foreground">
      <span className="flex items-center gap-1.5">
        <span className={`inline-block w-1.5 h-1.5 rounded-full ${app.bridgeAvailable ? 'bg-success' : 'bg-[var(--text-muted)]'}`} />
        Rig: {app.bridgeAvailable ? '14.074.000 USB' : 'Disconnected'}
      </span>
      <Separator orientation="vertical" className="h-3" />
      <span className="flex items-center gap-1.5">
        <span className={`inline-block w-1.5 h-1.5 rounded-full ${app.bridgeAvailable ? 'bg-success' : 'bg-[var(--text-muted)]'}`} />
        Cluster: {app.bridgeAvailable ? 'Connected' : 'Offline'}
      </span>
      <Separator orientation="vertical" className="h-3" />
      <span>QSOs: {logbook.totalCount}</span>
      <span className="ml-auto">{app.operatorCallsign || 'N0CALL'} &bull; {app.gridSquare || '----'}</span>
    </div>
  );
}
