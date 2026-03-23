import { useSnapshot } from 'valtio';
import { logbookStore } from '@/stores/logbook';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';

export function AwardsDashboard() {
  const snap = useSnapshot(logbookStore);

  const uniqueCallsigns = new Set(snap.qsos.map(q => q.callsign)).size;
  const uniqueBands = new Set(snap.qsos.map(q => q.band)).size;
  const uniqueModes = new Set(snap.qsos.map(q => q.mode)).size;

  return (
    <div className="flex-1 overflow-auto p-4">
      <h2 className="text-base font-semibold mb-4">Awards</h2>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-3 mb-6">
        <StatCard label="Unique Callsigns" value={uniqueCallsigns} />
        <StatCard label="Bands Used" value={uniqueBands} />
        <StatCard label="Modes Used" value={uniqueModes} />
      </div>

      <Tabs defaultValue="dxcc">
        <TabsList>
          <TabsTrigger value="dxcc">DXCC</TabsTrigger>
          <TabsTrigger value="was">WAS</TabsTrigger>
          <TabsTrigger value="waz">WAZ</TabsTrigger>
        </TabsList>

        <TabsContent value="dxcc">
          <DXCCView />
        </TabsContent>
        <TabsContent value="was">
          <PlaceholderView title="Worked All States" description="Track progress toward all 50 US states" />
        </TabsContent>
        <TabsContent value="waz">
          <PlaceholderView title="Worked All Zones" description="Track progress toward all 40 CQ zones" />
        </TabsContent>
      </Tabs>
    </div>
  );
}

function DXCCView() {
  const snap = useSnapshot(logbookStore);
  const bands = ['160m', '80m', '40m', '20m', '15m', '10m'];
  const callsigns = [...new Set(snap.qsos.map(q => q.callsign))];

  return (
    <div>
      <h3 className="text-xs font-semibold uppercase tracking-wider mb-3" style={{ color: 'var(--text-muted)' }}>
        DXCC Progress
      </h3>

      {callsigns.length === 0 ? (
        <p className="text-sm" style={{ color: 'var(--text-muted)' }}>Log some QSOs to see DXCC progress</p>
      ) : (
        <div className="overflow-auto">
          <table className="text-xs" style={{ borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                <th className="text-left px-2 py-1.5 font-mono" style={{ color: 'var(--text-muted)' }}>Callsign</th>
                {bands.map(b => (
                  <th key={b} className="px-2 py-1.5 text-center font-mono" style={{ color: 'var(--text-muted)', minWidth: 40 }}>{b}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {callsigns.slice(0, 20).map(call => (
                <tr key={call} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                  <td className="px-2 py-1.5">
                    <span className="font-mono font-medium" style={{ color: 'var(--accent-text)' }}>{call}</span>
                  </td>
                  {bands.map(b => {
                    const worked = snap.qsos.some(q => q.callsign === call && q.band === b);
                    return (
                      <td key={b} className="px-2 py-1.5 text-center">
                        <span className="inline-block w-3 h-3 rounded-sm" style={{ background: worked ? 'var(--green)' : 'var(--border-subtle)' }} />
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
      <div className="text-xl font-bold font-mono" style={{ color: 'var(--accent)' }}>{value}</div>
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
