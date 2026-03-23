import { useSnapshot } from 'valtio';
import { logbookStore } from '@/stores/logbook';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Label } from '@/components/ui/label';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table';

export function AwardsDashboard() {
  const snap = useSnapshot(logbookStore);
  const uniqueCallsigns = new Set(snap.qsos.map(q => q.callsign)).size;
  const uniqueBands = new Set(snap.qsos.map(q => q.band)).size;
  const uniqueModes = new Set(snap.qsos.map(q => q.mode)).size;

  return (
    <ScrollArea className="flex-1">
      <div className="p-4 space-y-4">
        <h2 className="text-base font-semibold">Awards</h2>

        <div className="grid grid-cols-3 gap-3">
          <Card><CardContent className="p-3 text-center">
            <div className="text-xl font-bold font-mono text-[var(--accent)]">{uniqueCallsigns}</div>
            <Label className="mt-1 block">Unique Callsigns</Label>
          </CardContent></Card>
          <Card><CardContent className="p-3 text-center">
            <div className="text-xl font-bold font-mono text-[var(--accent)]">{uniqueBands}</div>
            <Label className="mt-1 block">Bands Used</Label>
          </CardContent></Card>
          <Card><CardContent className="p-3 text-center">
            <div className="text-xl font-bold font-mono text-[var(--accent)]">{uniqueModes}</div>
            <Label className="mt-1 block">Modes Used</Label>
          </CardContent></Card>
        </div>

        <Tabs defaultValue="dxcc">
          <TabsList>
            <TabsTrigger value="dxcc">DXCC</TabsTrigger>
            <TabsTrigger value="was">WAS</TabsTrigger>
            <TabsTrigger value="waz">WAZ</TabsTrigger>
          </TabsList>
          <TabsContent value="dxcc"><DXCCView /></TabsContent>
          <TabsContent value="was">
            <div className="flex flex-col items-center justify-center py-12 text-[var(--text-muted)]">
              <p className="text-sm font-medium text-[var(--text-secondary)]">Worked All States</p>
              <p className="text-xs mt-1">Track progress toward all 50 US states</p>
            </div>
          </TabsContent>
          <TabsContent value="waz">
            <div className="flex flex-col items-center justify-center py-12 text-[var(--text-muted)]">
              <p className="text-sm font-medium text-[var(--text-secondary)]">Worked All Zones</p>
              <p className="text-xs mt-1">Track progress toward all 40 CQ zones</p>
            </div>
          </TabsContent>
        </Tabs>
      </div>
    </ScrollArea>
  );
}

function DXCCView() {
  const snap = useSnapshot(logbookStore);
  const bands = ['160m', '80m', '40m', '20m', '15m', '10m'];
  const callsigns = [...new Set(snap.qsos.map(q => q.callsign))];

  if (callsigns.length === 0) return <p className="text-sm text-[var(--text-muted)]">Log some QSOs to see DXCC progress</p>;

  return (
    <div>
      <Label className="mb-3 block">DXCC Progress</Label>
      <Table>
        <TableHeader>
          <TableRow className="hover:bg-transparent">
            <TableHead>Callsign</TableHead>
            {bands.map(b => <TableHead key={b} className="text-center min-w-[40px]">{b}</TableHead>)}
          </TableRow>
        </TableHeader>
        <TableBody>
          {callsigns.slice(0, 20).map(call => (
            <TableRow key={call}>
              <TableCell className="font-mono font-medium text-[var(--accent-text)]">{call}</TableCell>
              {bands.map(b => (
                <TableCell key={b} className="text-center">
                  <span className={`inline-block w-3 h-3 rounded-sm ${snap.qsos.some(q => q.callsign === call && q.band === b) ? 'bg-[var(--green)]' : 'bg-[var(--border-subtle)]'}`} />
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
}
