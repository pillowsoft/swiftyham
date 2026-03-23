import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { Play, Square } from 'lucide-react';

interface ContestQSO {
  id: string;
  callsign: string;
  exchange: string;
  band: string;
  time: string;
  isDupe: boolean;
  points: number;
}

const CONTESTS = [
  { id: 'cqww-cw', name: 'CQ WW CW' },
  { id: 'cqww-ssb', name: 'CQ WW SSB' },
  { id: 'arrl-dx', name: 'ARRL DX' },
  { id: 'naqp-cw', name: 'NAQP CW' },
  { id: 'wpx-cw', name: 'CQ WPX CW' },
];

export function ContestPanel() {
  const [active, setActive] = useState(false);
  const [contest, setContest] = useState('cqww-cw');
  const [callsign, setCallsign] = useState('');
  const [exchange, setExchange] = useState('');
  const [qsos, setQsos] = useState<ContestQSO[]>([]);
  const [serial, setSerial] = useState(1);

  function logContact() {
    if (!callsign.trim()) return;
    const qso: ContestQSO = {
      id: crypto.randomUUID(),
      callsign: callsign.toUpperCase(),
      exchange: exchange || '599',
      band: '20m',
      time: new Date().toISOString().slice(11, 16),
      isDupe: qsos.some(q => q.callsign === callsign.toUpperCase()),
      points: 3,
    };
    setQsos([qso, ...qsos]);
    setSerial(serial + 1);
    setCallsign('');
    setExchange('');
  }

  const totalPoints = qsos.filter(q => !q.isDupe).reduce((s, q) => s + q.points, 0);
  const validQsos = qsos.filter(q => !q.isDupe).length;

  return (
    <div className="flex-1 flex flex-col overflow-hidden p-4">
      <div className="flex items-center gap-3 mb-4">
        <h2 className="text-base font-semibold">Contest</h2>
        {!active ? (
          <>
            <Select value={contest} onValueChange={setContest}>
              <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
              <SelectContent>
                {CONTESTS.map(c => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}
              </SelectContent>
            </Select>
            <Button size="sm" onClick={() => setActive(true)}><Play size={12} /> Start</Button>
          </>
        ) : (
          <>
            <Badge>{CONTESTS.find(c => c.id === contest)?.name}</Badge>
            <Button size="sm" variant="destructive" onClick={() => setActive(false)}><Square size={12} /> Stop</Button>
          </>
        )}
      </div>

      {active && (
        <>
          {/* Score summary */}
          <div className="grid grid-cols-4 gap-2 mb-4">
            <ScoreCard label="QSOs" value={validQsos} />
            <ScoreCard label="Points" value={totalPoints} />
            <ScoreCard label="Mults" value={Math.floor(validQsos * 0.6)} />
            <ScoreCard label="Score" value={totalPoints * Math.max(1, Math.floor(validQsos * 0.6))} />
          </div>

          {/* Quick entry */}
          <div className="flex gap-2 mb-4">
            <Input
              className="font-mono uppercase flex-1"
              placeholder="Callsign"
              value={callsign}
              onChange={(e) => setCallsign(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') { if (exchange) logContact(); else document.getElementById('contest-exch')?.focus(); } }}
              autoFocus
            />
            <Input
              id="contest-exch"
              className="font-mono w-32"
              placeholder="Exchange"
              value={exchange}
              onChange={(e) => setExchange(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') logContact(); }}
            />
            <Button onClick={logContact} disabled={!callsign.trim()}>Log</Button>
          </div>

          <Separator className="mb-3" />

          {/* QSO list */}
          <div className="flex-1 overflow-auto">
            <table className="w-full text-xs" style={{ borderCollapse: 'collapse' }}>
              <thead>
                <tr>
                  {['#', 'Time', 'Callsign', 'Exch', 'Band', 'Pts'].map(h => (
                    <th key={h} className="text-left px-2 py-1.5 sticky top-0" style={{ color: 'var(--text-muted)', background: 'var(--bg)', borderBottom: '1px solid var(--border)', fontSize: 10, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {qsos.map((qso, i) => (
                  <tr key={qso.id} style={{ borderBottom: '1px solid var(--border-subtle)', opacity: qso.isDupe ? 0.4 : 1 }}>
                    <td className="px-2 py-1 font-mono" style={{ color: 'var(--text-muted)' }}>{qsos.length - i}</td>
                    <td className="px-2 py-1 font-mono" style={{ color: 'var(--text-muted)' }}>{qso.time}</td>
                    <td className="px-2 py-1 font-mono font-medium" style={{ color: qso.isDupe ? 'var(--red)' : 'var(--accent-text)' }}>
                      {qso.callsign} {qso.isDupe && <Badge variant="red" className="ml-1">DUPE</Badge>}
                    </td>
                    <td className="px-2 py-1 font-mono">{qso.exchange}</td>
                    <td className="px-2 py-1 font-mono">{qso.band}</td>
                    <td className="px-2 py-1 font-mono">{qso.isDupe ? 0 : qso.points}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}

      {!active && (
        <div className="flex-1 flex flex-col items-center justify-center" style={{ color: 'var(--text-muted)' }}>
          <p className="text-sm">Select a contest and click Start to begin operating</p>
          <p className="text-xs mt-1">Tab between callsign and exchange, Enter to log</p>
        </div>
      )}
    </div>
  );
}

function ScoreCard({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-md p-2 text-center" style={{ border: '1px solid var(--border)', background: 'var(--bg-surface)' }}>
      <div className="text-lg font-bold font-mono" style={{ color: 'var(--accent)' }}>{value.toLocaleString()}</div>
      <div className="text-[9px] uppercase tracking-wider" style={{ color: 'var(--text-muted)' }}>{label}</div>
    </div>
  );
}
