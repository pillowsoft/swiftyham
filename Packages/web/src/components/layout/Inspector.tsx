import { useSnapshot } from 'valtio';
import { appStore } from '@/stores/app';
import { logbookStore } from '@/stores/logbook';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Badge } from '@/components/ui/badge';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import { Radio } from 'lucide-react';

export function Inspector() {
  const app = useSnapshot(appStore);
  const logbook = useSnapshot(logbookStore);
  const qso = app.selectedQSOId ? logbook.qsos.find(q => q.id === app.selectedQSOId) : null;

  if (!qso) {
    return (
      <div className="flex flex-col items-center justify-center h-full px-4 text-muted-foreground">
        <Radio size={40} className="mb-3 opacity-30" />
        <p className="text-sm font-medium text-muted-foreground">Select a QSO</p>
        <p className="text-xs mt-1 text-center">Click a row in the logbook to see details here.</p>
      </div>
    );
  }

  return (
    <ScrollArea className="h-full">
      <div className="p-4 space-y-4">
        {/* Callsign */}
        <div>
          <Label>Callsign</Label>
          <div className="text-xl font-bold font-mono text-primary mt-1">{qso.callsign}</div>
        </div>

        <Separator />

        {/* Band / Mode / Freq */}
        <div className="grid grid-cols-3 gap-3">
          <div><Label>Band</Label><div className="font-mono text-sm mt-1">{qso.band}</div></div>
          <div><Label>Mode</Label><div className="mt-1"><Badge variant={qso.mode === 'CW' ? 'yellow' : 'default'}>{qso.mode}</Badge></div></div>
          <div><Label>Freq</Label><div className="font-mono text-sm mt-1">{(qso.frequencyHz / 1_000_000).toFixed(3)}</div></div>
        </div>

        <Separator />

        {/* RST */}
        <div className="grid grid-cols-2 gap-3">
          <div><Label>RST Sent</Label><div className="font-mono text-sm mt-1">{qso.rstSent}</div></div>
          <div><Label>RST Rcvd</Label><div className="font-mono text-sm mt-1">{qso.rstReceived}</div></div>
        </div>

        <Separator />

        {/* Date */}
        <div>
          <Label>Date/Time (UTC)</Label>
          <div className="font-mono text-sm mt-1">{new Date(qso.datetimeOn).toISOString().slice(0, 19).replace('T', ' ')}</div>
        </div>

        {/* Contact info */}
        {qso.name && <div><Label>Name</Label><div className="text-sm mt-1">{qso.name}</div></div>}
        {qso.qth && <div><Label>QTH</Label><div className="text-sm mt-1">{qso.qth}</div></div>}
        {qso.theirGrid && <div><Label>Grid</Label><div className="font-mono text-sm mt-1">{qso.theirGrid}</div></div>}
        {qso.comment && (
          <div>
            <Label>Comment</Label>
            <div className="text-xs text-muted-foreground mt-1">{qso.comment}</div>
          </div>
        )}
      </div>
    </ScrollArea>
  );
}
