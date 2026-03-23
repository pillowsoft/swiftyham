import { useState } from 'react';
import { useSnapshot } from 'valtio';
import { logbookStore } from '@/stores/logbook';

type AwardTab = 'dxcc' | 'was' | 'waz';

export function AwardsDashboard() {
  const [tab, setTab] = useState<AwardTab>('dxcc');
  const snap = useSnapshot(logbookStore);

  // Compute basic stats from logbook
  const uniqueCallsigns = new Set(snap.qsos.map(q => q.callsign)).size;
  const uniqueBands = new Set(snap.qsos.map(q => q.band)).size;
  const uniqueModes = new Set(snap.qsos.map(q => q.mode)).size;

  return (
    <div className="flex-1 overflow-auto p-4">
      <h2 className="text-base font-semibold mb-4">Awards</h2>

      {/* Tab selector */}
      <div className="flex gap-1 mb-4">
        {(['dxcc', 'was', 'waz'] as AwardTab[]).map(t => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className="px-3 py-1 rounded text-xs font-medium uppercase cursor-pointer"
            style={{
              background: tab === t ? 'var(--accent-dim)' : 'transparent',
              color: tab === t ? 'var(--accent)' : 'var(--text-secondary)',
              border: `1px solid ${tab === t ? 'var(--accent)' : 'var(--border)'}`,
            }}
          >
            {t}
          </button>
        ))}
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-3 mb-6">
        <StatCard label="Unique Callsigns" value={uniqueCallsigns} />
        <StatCard label="Bands Used" value={uniqueBands} />
        <StatCard label="Modes Used" value={uniqueModes} />
      </div>

      {/* Award content */}
      {tab === 'dxcc' && <DXCCView />}
      {tab === 'was' && <PlaceholderView title="Worked All States" description="Track your progress toward working all 50 US states" />}
      {tab === 'waz' && <PlaceholderView title="Worked All Zones" description="Track your progress toward working all 40 CQ zones" />}
    </div>
  );
}

function DXCCView() {
  const snap = useSnapshot(logbookStore);

  // Group QSOs by band for a simple matrix
  const bands = ['160m', '80m', '40m', '20m', '15m', '10m'];
  const callsigns = [...new Set(snap.qsos.map(q => q.callsign))];

  return (
    <div>
      <h3 className="text-xs font-semibold uppercase tracking-wider mb-3" style={{ color: 'var(--text-muted)' }}>
        DXCC Progress
      </h3>

      {callsigns.length === 0 ? (
        <p className="text-sm" style={{ color: 'var(--text-muted)' }}>Log some QSOs to see your DXCC progress</p>
      ) : (
        <div className="overflow-auto">
          <table className="text-xs" style={{ borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                <th className="text-left px-2 py-1" style={{ color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>Callsign</th>
                {bands.map(b => (
                  <th key={b} className="px-2 py-1 text-center" style={{ color: 'var(--text-muted)', fontFamily: 'var(--font-mono)', minWidth: 40 }}>
                    {b}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {callsigns.slice(0, 20).map(call => (
                <tr key={call} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                  <td className="px-2 py-1 font-medium" style={{ fontFamily: 'var(--font-mono)', color: 'var(--accent-text)' }}>
                    {call}
                  </td>
                  {bands.map(b => {
                    const worked = snap.qsos.some(q => q.callsign === call && q.band === b);
                    return (
                      <td key={b} className="px-2 py-1 text-center">
                        {worked ? (
                          <span className="inline-block w-3 h-3 rounded-sm" style={{ background: 'var(--green)' }} />
                        ) : (
                          <span className="inline-block w-3 h-3 rounded-sm" style={{ background: 'var(--border-subtle)' }} />
                        )}
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-md p-3 text-center" style={{ border: '1px solid var(--border)', background: 'var(--bg-surface)' }}>
      <div className="text-xl font-bold" style={{ fontFamily: 'var(--font-mono)', color: 'var(--accent)' }}>{value}</div>
      <div className="text-[10px] uppercase tracking-wider mt-1" style={{ color: 'var(--text-muted)' }}>{label}</div>
    </div>
  );
}

function PlaceholderView({ title, description }: { title: string; description: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-12" style={{ color: 'var(--text-muted)' }}>
      <p className="text-sm font-medium" style={{ color: 'var(--text-secondary)' }}>{title}</p>
      <p className="text-xs mt-1">{description}</p>
    </div>
  );
}
