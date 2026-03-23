import { useSnapshot } from 'valtio';
import { logbookStore } from '@/stores/logbook';
import { appStore } from '@/stores/app';
import { Badge } from '@/components/ui/badge';
import type { QSO } from '@hamstation/shared';

function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toISOString().slice(0, 16).replace('T', ' ');
}

function formatFreq(hz: number): string {
  return (hz / 1_000_000).toFixed(3);
}

function modeBadgeVariant(mode: string): 'default' | 'yellow' | 'gray' {
  if (['FT8', 'FT4', 'JS8', 'WSPR'].includes(mode)) return 'default';
  if (mode === 'CW') return 'yellow';
  return 'gray';
}

export function LogbookTable() {
  const snap = useSnapshot(logbookStore);
  const app = useSnapshot(appStore);

  return (
    <div className="flex-1 overflow-auto">
      <table className="w-full" style={{ borderCollapse: 'collapse', fontSize: 12 }}>
        <thead>
          <tr>
            {['Date/Time', 'Callsign', 'Band', 'Mode', 'Freq', 'RST S', 'RST R', 'Name'].map(h => (
              <th
                key={h}
                className="text-left sticky top-0 z-10"
                style={{
                  padding: '6px 8px',
                  fontWeight: 500,
                  fontSize: 11,
                  color: 'var(--text-muted)',
                  borderBottom: '1px solid var(--border)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.05em',
                  background: 'var(--bg)',
                }}
              >
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {snap.qsos.map((qso) => {
            const selected = app.selectedQSOId === qso.id;
            return (
              <tr
                key={qso.id}
                onClick={() => { appStore.selectedQSOId = qso.id; }}
                className="cursor-pointer"
                style={{
                  background: selected ? 'var(--accent-dim)' : undefined,
                }}
                onMouseEnter={(e) => {
                  if (!selected) (e.currentTarget as HTMLElement).style.background = 'var(--bg-tertiary)';
                }}
                onMouseLeave={(e) => {
                  if (!selected) (e.currentTarget as HTMLElement).style.background = '';
                }}
              >
                <td style={cellStyle}>
                  <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-muted)', fontSize: 11 }}>
                    {formatTime(qso.datetimeOn)}
                  </span>
                </td>
                <td style={cellStyle}>
                  <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, color: 'var(--accent-text)' }}>
                    {qso.callsign}
                  </span>
                </td>
                <td style={{ ...cellStyle, fontFamily: 'var(--font-mono)' }}>{qso.band}</td>
                <td style={cellStyle}>
                  <Badge variant={modeBadgeVariant(qso.mode)}>{qso.mode}</Badge>
                </td>
                <td style={{ ...cellStyle, fontFamily: 'var(--font-mono)', color: 'var(--text-secondary)' }}>
                  {formatFreq(qso.frequencyHz)}
                </td>
                <td style={{ ...cellStyle, fontFamily: 'var(--font-mono)' }}>{qso.rstSent}</td>
                <td style={{ ...cellStyle, fontFamily: 'var(--font-mono)' }}>{qso.rstReceived}</td>
                <td style={cellStyle}>{qso.name || ''}</td>
              </tr>
            );
          })}
        </tbody>
      </table>

      {snap.qsos.length === 0 && (
        <div className="flex flex-col items-center justify-center py-20" style={{ color: 'var(--text-muted)' }}>
          <p className="text-lg font-medium">No QSOs yet</p>
          <p className="text-sm mt-1">Import an ADIF file or log your first contact</p>
        </div>
      )}
    </div>
  );
}

const cellStyle: React.CSSProperties = {
  padding: '5px 8px',
  borderBottom: '1px solid var(--border-subtle)',
};
