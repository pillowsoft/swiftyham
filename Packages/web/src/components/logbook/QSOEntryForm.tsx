import { useState } from 'react';
import { createQSO, addQSO } from '@/stores/logbook';
import { appStore } from '@/stores/app';
import { ALL_BANDS, type BandId, bandForFrequency } from '@hamstation/shared';
import { ALL_MODES, defaultRST, type OperatingMode } from '@hamstation/shared';
import { lookupCallsign } from '@hamstation/shared/src/callsign/lookup';
import { parseNaturalLanguage } from '@hamstation/shared/src/ai/natural-language-logger';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select';
import { Separator } from '@/components/ui/separator';
import { Mic, Search, Loader2 } from 'lucide-react';

interface Props {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function QSOEntryForm({ open, onOpenChange }: Props) {
  const [callsign, setCallsign] = useState('');
  const [band, setBand] = useState<BandId>('20m');
  const [mode, setMode] = useState<OperatingMode>('FT8');
  const [frequency, setFrequency] = useState('14.074');
  const [rstSent, setRstSent] = useState('-10');
  const [rstReceived, setRstReceived] = useState('-10');
  const [name, setName] = useState('');
  const [qth, setQth] = useState('');
  const [grid, setGrid] = useState('');
  const [comment, setComment] = useState('');
  const [nlText, setNlText] = useState('');
  const [isLookingUp, setIsLookingUp] = useState(false);
  const [lookupStatus, setLookupStatus] = useState<'none' | 'found' | 'not_found' | 'error'>('none');

  async function handleLookup() {
    if (!callsign.trim()) return;
    setIsLookingUp(true);
    setLookupStatus('none');
    const result = await lookupCallsign(callsign);
    setIsLookingUp(false);
    setLookupStatus(result.status);
    if (result.status === 'found') {
      if (result.name && !name) setName(result.name);
      if (result.qth && !qth) setQth(result.qth);
      if (result.grid && !grid) setGrid(result.grid);
    }
  }

  function handleModeChange(newMode: OperatingMode) {
    setMode(newMode);
    setRstSent(defaultRST(newMode));
    setRstReceived(defaultRST(newMode));
  }

  function handleFrequencyChange(val: string) {
    setFrequency(val);
    const hz = parseFloat(val) * 1_000_000;
    if (!isNaN(hz)) {
      const detected = bandForFrequency(hz);
      if (detected) setBand(detected);
    }
  }

  function handleSave() {
    if (!callsign.trim()) return;
    const hz = parseFloat(frequency) * 1_000_000 || 14_074_000;
    const qso = createQSO({
      callsign: callsign.toUpperCase().trim(),
      myCallsign: appStore.operatorCallsign || 'N0CALL',
      band, mode, frequencyHz: hz, rstSent, rstReceived,
      name: name || undefined, qth: qth || undefined,
      theirGrid: grid || undefined, comment: comment || undefined,
    });
    addQSO(qso);
    resetForm();
    onOpenChange(false);
  }

  function resetForm() {
    setCallsign(''); setName(''); setQth(''); setGrid(''); setComment(''); setNlText('');
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>New QSO</DialogTitle>
          <DialogDescription>Log a new contact. Press ⌘N to open this form.</DialogDescription>
        </DialogHeader>

        {/* NL Entry bar */}
        <div className="flex items-center gap-2 px-5 py-2 -mx-0 rounded-md bg-background">
          <Mic size={14} className="text-muted-foreground" />
          <input
            className="flex-1 bg-transparent text-xs outline-none text-muted-foreground"
            placeholder='Type: "Worked JA1ABC on 20m FT8, -10 both ways"'
            value={nlText}
            onChange={(e) => setNlText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && nlText.trim()) {
                const parsed = parseNaturalLanguage(nlText);
                if (parsed.callsign) setCallsign(parsed.callsign);
                if (parsed.band) setBand(parsed.band as BandId);
                if (parsed.mode) { handleModeChange(parsed.mode as OperatingMode); }
                if (parsed.rstSent) setRstSent(parsed.rstSent);
                if (parsed.rstReceived) setRstReceived(parsed.rstReceived);
                setNlText('');
                // Auto-lookup if we got a callsign
                if (parsed.callsign) setTimeout(() => handleLookup(), 100);
              }
            }}
          />
        </div>

        <Separator />

        {/* Form fields */}
        <div className="px-5 pb-2 flex flex-col gap-3">
          {/* Callsign */}
          <div>
            <Label>Callsign</Label>
            <div className="flex gap-1.5">
              <Input
                className="font-mono text-lg font-bold uppercase flex-1 text-primary"
                value={callsign}
                onChange={(e) => setCallsign(e.target.value)}
                onBlur={() => { if (callsign.trim().length >= 3) handleLookup(); }}
                placeholder="W1AW"
                autoFocus
              />
              <Button variant="secondary" size="icon" onClick={handleLookup} disabled={isLookingUp || callsign.trim().length < 3} title="Lookup callsign">
                {isLookingUp ? <Loader2 size={14} className="animate-spin" /> : <Search size={14} />}
              </Button>
            </div>
            {lookupStatus === 'found' && <Badge variant="green" className="mt-1">Found</Badge>}
            {lookupStatus === 'not_found' && <Badge variant="yellow" className="mt-1">Not in HamDB</Badge>}
          </div>

          {/* Band / Mode / Freq */}
          <div className="grid grid-cols-3 gap-2">
            <div>
              <Label>Band</Label>
              <Select value={band} onValueChange={(v) => setBand(v as BandId)}>
                <SelectTrigger className="font-mono"><SelectValue /></SelectTrigger>
                <SelectContent>
                  {ALL_BANDS.map(b => <SelectItem key={b} value={b} className="font-mono">{b}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div>
              <Label>Mode</Label>
              <Select value={mode} onValueChange={(v) => handleModeChange(v as OperatingMode)}>
                <SelectTrigger className="font-mono"><SelectValue /></SelectTrigger>
                <SelectContent>
                  {ALL_MODES.map(m => <SelectItem key={m} value={m} className="font-mono">{m}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div>
              <Label>Freq (MHz)</Label>
              <Input className="font-mono" value={frequency} onChange={(e) => handleFrequencyChange(e.target.value)} />
            </div>
          </div>

          {/* RST */}
          <div className="grid grid-cols-2 gap-2">
            <div>
              <Label>RST Sent</Label>
              <Input className="font-mono" value={rstSent} onChange={(e) => setRstSent(e.target.value)} />
            </div>
            <div>
              <Label>RST Rcvd</Label>
              <Input className="font-mono" value={rstReceived} onChange={(e) => setRstReceived(e.target.value)} />
            </div>
          </div>

          {/* Contact info */}
          <div className="grid grid-cols-3 gap-2">
            <div>
              <Label>Name</Label>
              <Input value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div>
              <Label>QTH</Label>
              <Input value={qth} onChange={(e) => setQth(e.target.value)} />
            </div>
            <div>
              <Label>Grid</Label>
              <Input className="font-mono uppercase" value={grid} onChange={(e) => setGrid(e.target.value)} placeholder="FN31" />
            </div>
          </div>

          {/* Comment */}
          <div>
            <Label>Comment</Label>
            <textarea
              className="flex w-full rounded-md border border-border bg-background px-3 py-1.5 text-sm text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring resize-none"
              rows={2}
              value={comment}
              onChange={(e) => setComment(e.target.value)}
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="secondary" onClick={() => onOpenChange(false)}>Cancel</Button>
          <Button onClick={handleSave} disabled={!callsign.trim()}>Log QSO</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function Label({ children }: { children: React.ReactNode }) {
  return (
    <label className="text-[10px] uppercase tracking-wider mb-1 block text-muted-foreground">
      {children}
    </label>
  );
}
