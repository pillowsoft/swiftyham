import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent } from '@/components/ui/card';
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table';
import { Play, Square } from 'lucide-react';

interface ContestQSO { id: string; callsign: string; exchange: string; band: string; time: string; isDupe: boolean; points: number; }
const CONTESTS = [
  { id: 'cqww-cw', name: 'CQ WW CW' }, { id: 'cqww-ssb', name: 'CQ WW SSB' },
  { id: 'arrl-dx', name: 'ARRL DX' }, { id: 'naqp-cw', name: 'NAQP CW' }, { id: 'wpx-cw', name: 'CQ WPX CW' },
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
    const qso: ContestQSO = { id: crypto.randomUUID(), callsign: callsign.toUpperCase(), exchange: exchange || '599',
      band: '20m', time: new Date().toISOString().slice(11, 16), isDupe: qsos.some(q => q.callsign === callsign.toUpperCase()), points: 3 };
    setQsos([qso, ...qsos]); setSerial(serial + 1); setCallsign(''); setExchange('');
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
              <SelectContent>{CONTESTS.map(c => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}</SelectContent>
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
          <div className="grid grid-cols-4 gap-2 mb-4">
            {[['QSOs', validQsos], ['Points', totalPoints], ['Mults', Math.floor(validQsos * 0.6)], ['Score', totalPoints * Math.max(1, Math.floor(validQsos * 0.6))]].map(([label, value]) => (
              <Card key={label as string}><CardContent className="p-2 text-center">
                <div className="text-lg font-bold font-mono text-[var(--accent)]">{(value as number).toLocaleString()}</div>
                <Label className="block mt-0.5">{label as string}</Label>
              </CardContent></Card>
            ))}
          </div>

          <div className="flex gap-2 mb-4">
            <Input className="font-mono uppercase flex-1" placeholder="Callsign" value={callsign}
              onChange={(e) => setCallsign(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') { if (exchange) logContact(); else document.getElementById('contest-exch')?.focus(); } }}
              autoFocus />
            <Input id="contest-exch" className="font-mono w-32" placeholder="Exchange" value={exchange}
              onChange={(e) => setExchange(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') logContact(); }} />
            <Button onClick={logContact} disabled={!callsign.trim()}>Log</Button>
          </div>

          <Separator className="mb-3" />

          <ScrollArea className="flex-1">
            <Table>
              <TableHeader>
                <TableRow className="hover:bg-transparent">
                  <TableHead>#</TableHead><TableHead>Time</TableHead><TableHead>Callsign</TableHead>
                  <TableHead>Exch</TableHead><TableHead>Band</TableHead><TableHead>Pts</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {qsos.map((qso, i) => (
                  <TableRow key={qso.id} className={qso.isDupe ? 'opacity-40' : ''}>
                    <TableCell className="font-mono text-[var(--text-muted)]">{qsos.length - i}</TableCell>
                    <TableCell className="font-mono text-[var(--text-muted)]">{qso.time}</TableCell>
                    <TableCell className={`font-mono font-medium ${qso.isDupe ? 'text-[var(--red)]' : 'text-[var(--accent-text)]'}`}>
                      {qso.callsign} {qso.isDupe && <Badge variant="red" className="ml-1">DUPE</Badge>}
                    </TableCell>
                    <TableCell className="font-mono">{qso.exchange}</TableCell>
                    <TableCell className="font-mono">{qso.band}</TableCell>
                    <TableCell className="font-mono">{qso.isDupe ? 0 : qso.points}</TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </ScrollArea>
        </>
      )}

      {!active && (
        <div className="flex-1 flex flex-col items-center justify-center text-[var(--text-muted)]">
          <p className="text-sm">Select a contest and click Start to begin operating</p>
          <p className="text-xs mt-1">Tab between callsign and exchange, Enter to log</p>
        </div>
      )}
    </div>
  );
}
