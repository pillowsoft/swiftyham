import { useState } from 'react';
import { logbookStore, createQSO } from '@/stores/logbook';
import { appStore } from '@/stores/app';
import { ALL_BANDS, type BandId, bandForFrequency } from '@hamstation/shared';
import { ALL_MODES, defaultRST, type OperatingMode } from '@hamstation/shared';
import { X, Mic } from 'lucide-react';

interface Props {
  onClose: () => void;
}

export function QSOEntryForm({ onClose }: Props) {
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

  function handleModeChange(newMode: OperatingMode) {
    setMode(newMode);
    const rst = defaultRST(newMode);
    setRstSent(rst);
    setRstReceived(rst);
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
      band,
      mode,
      frequencyHz: hz,
      rstSent,
      rstReceived,
      name: name || undefined,
      qth: qth || undefined,
      theirGrid: grid || undefined,
      comment: comment || undefined,
    });
    logbookStore.qsos.unshift(qso);
    logbookStore.totalCount++;
    onClose();
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center" style={{ background: 'rgba(0,0,0,0.6)' }}>
      <div
        className="rounded-lg overflow-hidden flex flex-col"
        style={{ width: 460, background: 'var(--bg-surface)', border: '1px solid var(--border)' }}
      >
        {/* Header */}
        <div className="flex items-center justify-between px-4 py-3" style={{ borderBottom: '1px solid var(--border)' }}>
          <span className="font-semibold text-sm">New QSO</span>
          <button onClick={onClose} className="cursor-pointer" style={{ color: 'var(--text-muted)' }}>
            <X size={16} />
          </button>
        </div>

        {/* NL Entry bar */}
        <div className="flex items-center gap-2 px-4 py-2" style={{ borderBottom: '1px solid var(--border-subtle)', background: 'var(--bg)' }}>
          <Mic size={14} style={{ color: 'var(--text-muted)' }} />
          <input
            className="flex-1 bg-transparent text-xs outline-none"
            style={{ color: 'var(--text-secondary)' }}
            placeholder='e.g. "Worked JA1ABC on 20m FT8, -10 both ways"'
            value={nlText}
            onChange={(e) => setNlText(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && nlText.trim()) {
                // Simple NL parsing (will connect to shared lib later)
                const upper = nlText.toUpperCase();
                const callMatch = upper.match(/\b([A-Z]{1,2}\d[A-Z0-9]?\d?[A-Z]{1,4})\b/);
                if (callMatch) setCallsign(callMatch[1]);
                setNlText('');
              }
            }}
          />
        </div>

        {/* Form */}
        <div className="px-4 py-3 flex flex-col gap-3 overflow-y-auto" style={{ maxHeight: 400 }}>
          {/* Callsign */}
          <div>
            <FieldLabel>Callsign</FieldLabel>
            <input
              className="w-full rounded px-2 py-1.5 text-lg font-bold outline-none"
              style={{
                fontFamily: 'var(--font-mono)',
                color: 'var(--accent)',
                background: 'var(--bg)',
                border: '1px solid var(--border)',
                textTransform: 'uppercase',
              }}
              value={callsign}
              onChange={(e) => setCallsign(e.target.value)}
              placeholder="W1AW"
              autoFocus
            />
          </div>

          {/* Band / Mode / Freq */}
          <div className="grid grid-cols-3 gap-2">
            <div>
              <FieldLabel>Band</FieldLabel>
              <select
                className="w-full rounded px-2 py-1.5 text-sm outline-none cursor-pointer"
                style={{ fontFamily: 'var(--font-mono)', background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
                value={band}
                onChange={(e) => setBand(e.target.value as BandId)}
              >
                {ALL_BANDS.map(b => <option key={b} value={b}>{b}</option>)}
              </select>
            </div>
            <div>
              <FieldLabel>Mode</FieldLabel>
              <select
                className="w-full rounded px-2 py-1.5 text-sm outline-none cursor-pointer"
                style={{ fontFamily: 'var(--font-mono)', background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
                value={mode}
                onChange={(e) => handleModeChange(e.target.value as OperatingMode)}
              >
                {ALL_MODES.map(m => <option key={m} value={m}>{m}</option>)}
              </select>
            </div>
            <div>
              <FieldLabel>Freq (MHz)</FieldLabel>
              <input
                className="w-full rounded px-2 py-1.5 text-sm outline-none"
                style={{ fontFamily: 'var(--font-mono)', background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
                value={frequency}
                onChange={(e) => handleFrequencyChange(e.target.value)}
              />
            </div>
          </div>

          {/* RST */}
          <div className="grid grid-cols-2 gap-2">
            <div>
              <FieldLabel>RST Sent</FieldLabel>
              <input
                className="w-full rounded px-2 py-1.5 text-sm outline-none"
                style={{ fontFamily: 'var(--font-mono)', background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
                value={rstSent}
                onChange={(e) => setRstSent(e.target.value)}
              />
            </div>
            <div>
              <FieldLabel>RST Rcvd</FieldLabel>
              <input
                className="w-full rounded px-2 py-1.5 text-sm outline-none"
                style={{ fontFamily: 'var(--font-mono)', background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
                value={rstReceived}
                onChange={(e) => setRstReceived(e.target.value)}
              />
            </div>
          </div>

          {/* Name / QTH / Grid */}
          <div className="grid grid-cols-3 gap-2">
            <div>
              <FieldLabel>Name</FieldLabel>
              <input className="w-full rounded px-2 py-1.5 text-sm outline-none"
                style={{ background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
                value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div>
              <FieldLabel>QTH</FieldLabel>
              <input className="w-full rounded px-2 py-1.5 text-sm outline-none"
                style={{ background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
                value={qth} onChange={(e) => setQth(e.target.value)} />
            </div>
            <div>
              <FieldLabel>Grid</FieldLabel>
              <input className="w-full rounded px-2 py-1.5 text-sm outline-none"
                style={{ fontFamily: 'var(--font-mono)', background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)', textTransform: 'uppercase' }}
                value={grid} onChange={(e) => setGrid(e.target.value)} placeholder="FN31" />
            </div>
          </div>

          {/* Comment */}
          <div>
            <FieldLabel>Comment</FieldLabel>
            <textarea
              className="w-full rounded px-2 py-1.5 text-sm outline-none resize-none"
              style={{ background: 'var(--bg)', border: '1px solid var(--border)', color: 'var(--text)' }}
              rows={2}
              value={comment}
              onChange={(e) => setComment(e.target.value)}
            />
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-end gap-2 px-4 py-3" style={{ borderTop: '1px solid var(--border)' }}>
          <button
            onClick={onClose}
            className="px-3 py-1.5 rounded text-sm cursor-pointer"
            style={{ border: '1px solid var(--border)', color: 'var(--text-secondary)' }}
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="px-4 py-1.5 rounded text-sm font-medium cursor-pointer"
            style={{ background: 'var(--accent)', color: 'white', opacity: callsign.trim() ? 1 : 0.5 }}
            disabled={!callsign.trim()}
          >
            Log QSO
          </button>
        </div>
      </div>
    </div>
  );
}

function FieldLabel({ children }: { children: React.ReactNode }) {
  return (
    <label className="text-[10px] uppercase tracking-wider mb-0.5 block" style={{ color: 'var(--text-muted)', letterSpacing: '0.05em' }}>
      {children}
    </label>
  );
}
