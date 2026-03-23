import { useSnapshot } from 'valtio';
import { appStore } from '@/stores/app';
import { logbookStore } from '@/stores/logbook';

export function StatusBar() {
  const app = useSnapshot(appStore);
  const logbook = useSnapshot(logbookStore);

  return (
    <div
      className="flex items-center gap-4 text-[11px]"
      style={{
        height: 34,
        paddingLeft: 14,
        paddingRight: 14,
        paddingBottom: 8,
        background: 'var(--bg-surface)',
        borderTop: '1px solid var(--border)',
        color: 'var(--text-muted)',
        fontFamily: 'var(--font-mono)',
      }}
    >
      <span>
        <Dot color={app.bridgeAvailable ? 'var(--green)' : 'var(--text-muted)'} />
        {' '}Rig: {app.bridgeAvailable ? '14.074.000 USB' : 'Disconnected'}
      </span>
      <span>
        <Dot color={app.bridgeAvailable ? 'var(--green)' : 'var(--text-muted)'} />
        {' '}Cluster: {app.bridgeAvailable ? 'Connected' : 'Offline'}
      </span>
      <span>QSOs: {logbook.totalCount}</span>
      <span className="ml-auto">{app.operatorCallsign || 'N0CALL'} • {app.gridSquare || '----'}</span>
    </div>
  );
}

function Dot({ color }: { color: string }) {
  return (
    <span
      className="inline-block rounded-full"
      style={{ width: 6, height: 6, background: color, verticalAlign: 'middle' }}
    />
  );
}
