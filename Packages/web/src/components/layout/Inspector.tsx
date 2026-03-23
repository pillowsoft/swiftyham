import { useSnapshot } from 'valtio';
import { appStore } from '@/stores/app';
import { logbookStore } from '@/stores/logbook';
import { Radio } from 'lucide-react';

export function Inspector() {
  const app = useSnapshot(appStore);
  const logbook = useSnapshot(logbookStore);

  const selectedQSO = app.selectedQSOId
    ? logbook.qsos.find(q => q.id === app.selectedQSOId)
    : null;

  if (!selectedQSO) {
    return (
      <div className="flex flex-col items-center justify-center h-full px-4" style={{ color: 'var(--text-muted)' }}>
        <Radio size={40} className="mb-3 opacity-30" />
        <p className="text-sm font-medium" style={{ color: 'var(--text-secondary)' }}>Select a QSO</p>
        <p className="text-xs mt-1 text-center">Click a row in the logbook to see details here.</p>
      </div>
    );
  }

  return (
    <div className="p-3 overflow-y-auto h-full">
      {/* Callsign */}
      <div className="mb-4">
        <Label>Callsign</Label>
        <div
          className="text-xl font-bold"
          style={{ fontFamily: 'var(--font-mono)', color: 'var(--accent)' }}
        >
          {selectedQSO.callsign}
        </div>
      </div>

      {/* Band / Mode / Freq */}
      <div className="grid grid-cols-3 gap-2 mb-4">
        <div>
          <Label>Band</Label>
          <Value>{selectedQSO.band}</Value>
        </div>
        <div>
          <Label>Mode</Label>
          <Value>{selectedQSO.mode}</Value>
        </div>
        <div>
          <Label>Freq</Label>
          <Value>{(selectedQSO.frequencyHz / 1_000_000).toFixed(3)}</Value>
        </div>
      </div>

      {/* RST */}
      <div className="grid grid-cols-2 gap-2 mb-4">
        <div>
          <Label>RST Sent</Label>
          <Value>{selectedQSO.rstSent}</Value>
        </div>
        <div>
          <Label>RST Rcvd</Label>
          <Value>{selectedQSO.rstReceived}</Value>
        </div>
      </div>

      {/* Date */}
      <div className="mb-4">
        <Label>Date/Time (UTC)</Label>
        <Value>{new Date(selectedQSO.datetimeOn).toISOString().slice(0, 19).replace('T', ' ')}</Value>
      </div>

      {/* Name / QTH / Grid */}
      {selectedQSO.name && (
        <div className="mb-3">
          <Label>Name</Label>
          <div className="text-sm">{selectedQSO.name}</div>
        </div>
      )}
      {selectedQSO.qth && (
        <div className="mb-3">
          <Label>QTH</Label>
          <div className="text-sm">{selectedQSO.qth}</div>
        </div>
      )}
      {selectedQSO.theirGrid && (
        <div className="mb-3">
          <Label>Grid</Label>
          <Value>{selectedQSO.theirGrid}</Value>
        </div>
      )}

      {/* Comment */}
      {selectedQSO.comment && (
        <div className="mb-3">
          <Label>Comment</Label>
          <div className="text-xs" style={{ color: 'var(--text-secondary)' }}>{selectedQSO.comment}</div>
        </div>
      )}
    </div>
  );
}

function Label({ children }: { children: React.ReactNode }) {
  return (
    <div
      className="text-[10px] uppercase tracking-wider mb-0.5"
      style={{ color: 'var(--text-muted)', letterSpacing: '0.05em' }}
    >
      {children}
    </div>
  );
}

function Value({ children }: { children: React.ReactNode }) {
  return (
    <div className="text-[13px]" style={{ fontFamily: 'var(--font-mono)' }}>
      {children}
    </div>
  );
}
