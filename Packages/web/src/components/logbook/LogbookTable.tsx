import { useState } from 'react';
import { useSnapshot } from 'valtio';
import { logbookStore, deleteQSO, refreshLogbook } from '@/stores/logbook';
import { appStore } from '@/stores/app';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Separator } from '@/components/ui/separator';
import { Trash2, Search } from 'lucide-react';
import { ALL_BANDS, type BandId } from '@hamstation/shared';
import { cn } from '@/lib/cn';
import type { QSO } from '@hamstation/shared';

function formatTime(iso: string): string {
  return new Date(iso).toISOString().slice(0, 16).replace('T', ' ');
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
  const [search, setSearch] = useState('');
  const [bandFilter, setBandFilter] = useState<string>('all');

  const filtered = snap.qsos.filter(qso => {
    if (search && !qso.callsign.toLowerCase().includes(search.toLowerCase()) && !(qso.name || '').toLowerCase().includes(search.toLowerCase())) return false;
    if (bandFilter !== 'all' && qso.band !== bandFilter) return false;
    return true;
  });

  function handleDelete() {
    if (app.selectedQSOId && confirm('Delete this QSO?')) {
      deleteQSO(app.selectedQSOId);
      appStore.selectedQSOId = null;
    }
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      {/* Filter bar */}
      <div className="flex items-center gap-2 px-3 py-2 border-b border-border">
        <Search size={14} className="text-muted-foreground" />
        <Input
          className="flex-1"
          placeholder="Search callsign or name..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <Select value={bandFilter} onValueChange={setBandFilter}>
          <SelectTrigger className="w-28"><SelectValue placeholder="Band" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All</SelectItem>
            {ALL_BANDS.map(b => <SelectItem key={b} value={b} className="font-mono">{b}</SelectItem>)}
          </SelectContent>
        </Select>
        {app.selectedQSOId && (
          <Button variant="ghost" size="icon" onClick={handleDelete} title="Delete QSO">
            <Trash2 size={14} className="text-destructive" />
          </Button>
        )}
        <span className="text-[10px] font-mono text-muted-foreground">
          {filtered.length} / {snap.totalCount}
        </span>
      </div>

      {/* Table */}
      <ScrollArea className="flex-1">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent">
              <TableHead>Date/Time</TableHead>
              <TableHead>Callsign</TableHead>
              <TableHead>Band</TableHead>
              <TableHead>Mode</TableHead>
              <TableHead>Freq</TableHead>
              <TableHead>RST S</TableHead>
              <TableHead>RST R</TableHead>
              <TableHead>Name</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filtered.map((qso) => (
              <TableRow
                key={qso.id}
                onClick={() => { appStore.selectedQSOId = qso.id; }}
                data-state={app.selectedQSOId === qso.id ? 'selected' : undefined}
              >
                <TableCell className="font-mono text-[11px] text-muted-foreground">
                  {formatTime(qso.datetimeOn)}
                </TableCell>
                <TableCell className="font-mono font-semibold text-primary">
                  {qso.callsign}
                </TableCell>
                <TableCell className="font-mono">{qso.band}</TableCell>
                <TableCell><Badge variant={modeBadgeVariant(qso.mode)}>{qso.mode}</Badge></TableCell>
                <TableCell className="font-mono text-muted-foreground">{formatFreq(qso.frequencyHz)}</TableCell>
                <TableCell className="font-mono">{qso.rstSent}</TableCell>
                <TableCell className="font-mono">{qso.rstReceived}</TableCell>
                <TableCell className="text-muted-foreground">{qso.name || ''}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>

        {filtered.length === 0 && (
          <div className="flex flex-col items-center justify-center py-20 text-muted-foreground">
            <p className="text-lg font-medium">No QSOs yet</p>
            <p className="text-sm mt-1">Import an ADIF file or log your first contact</p>
          </div>
        )}
      </ScrollArea>
    </div>
  );
}
