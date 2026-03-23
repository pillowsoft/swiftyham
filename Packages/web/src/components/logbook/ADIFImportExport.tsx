import { useRef } from 'react';
import { logbookStore, createQSO } from '@/stores/logbook';
import { appStore } from '@/stores/app';
import { parseADIF, exportADIF, createRecord } from '@hamstation/shared/src/adif/parser';
import type { BandId } from '@hamstation/shared';
import type { OperatingMode } from '@hamstation/shared';
import { Button } from '@/components/ui/button';
import { Upload, Download } from 'lucide-react';

export function ImportButton() {
  const fileRef = useRef<HTMLInputElement>(null);

  async function handleFile(file: File) {
    const text = await file.text();
    const result = parseADIF(text, 'lenient');

    let imported = 0;
    for (const record of result.records) {
      const callsign = record.get('CALL');
      if (!callsign) continue;

      const band = (record.get('BAND') || '20m') as BandId;
      const mode = (record.get('MODE') || 'SSB') as OperatingMode;
      const freqMHz = parseFloat(record.get('FREQ') || '14.074');
      const dateStr = record.get('QSO_DATE') || '';
      const timeStr = record.get('TIME_ON') || '';

      // Parse ADIF date (YYYYMMDD) + time (HHMM or HHMMSS) to ISO
      let datetimeOn = new Date().toISOString();
      if (dateStr.length === 8) {
        const y = dateStr.slice(0, 4);
        const m = dateStr.slice(4, 6);
        const d = dateStr.slice(6, 8);
        const hr = timeStr.slice(0, 2) || '00';
        const mn = timeStr.slice(2, 4) || '00';
        const sc = timeStr.slice(4, 6) || '00';
        datetimeOn = `${y}-${m}-${d}T${hr}:${mn}:${sc}Z`;
      }

      const qso = createQSO({
        callsign: callsign.toUpperCase(),
        myCallsign: record.get('STATION_CALLSIGN') || appStore.operatorCallsign || 'N0CALL',
        band,
        mode,
        frequencyHz: freqMHz * 1_000_000,
        datetimeOn,
        rstSent: record.get('RST_SENT') || '59',
        rstReceived: record.get('RST_RCVD') || '59',
        name: record.get('NAME') || undefined,
        qth: record.get('QTH') || undefined,
        theirGrid: record.get('GRIDSQUARE') || undefined,
        comment: record.get('COMMENT') || undefined,
      });

      logbookStore.qsos.push(qso);
      imported++;
    }

    logbookStore.totalCount = logbookStore.qsos.length;

    if (result.warnings.length > 0) {
      console.warn(`ADIF import: ${imported} QSOs imported, ${result.warnings.length} warnings`);
    }

    alert(`Imported ${imported} QSOs from ${file.name}${result.warnings.length ? ` (${result.warnings.length} warnings)` : ''}`);
  }

  return (
    <>
      <input
        ref={fileRef}
        type="file"
        accept=".adi,.adif"
        className="hidden"
        onChange={(e) => {
          const file = e.target.files?.[0];
          if (file) handleFile(file);
          e.target.value = '';
        }}
      />
      <Button variant="ghost" size="sm" onClick={() => fileRef.current?.click()} title="Import ADIF">
        <Upload size={14} /> Import
      </Button>
    </>
  );
}

export function ExportButton() {
  function handleExport() {
    const records = logbookStore.qsos.map(qso => {
      const fields = [
        { name: 'CALL', value: qso.callsign },
        { name: 'BAND', value: qso.band },
        { name: 'MODE', value: qso.mode },
        { name: 'FREQ', value: (qso.frequencyHz / 1_000_000).toFixed(6) },
        { name: 'QSO_DATE', value: qso.datetimeOn.slice(0, 10).replace(/-/g, '') },
        { name: 'TIME_ON', value: qso.datetimeOn.slice(11, 19).replace(/:/g, '') },
        { name: 'RST_SENT', value: qso.rstSent },
        { name: 'RST_RCVD', value: qso.rstReceived },
        { name: 'STATION_CALLSIGN', value: qso.myCallsign },
      ];
      if (qso.name) fields.push({ name: 'NAME', value: qso.name });
      if (qso.qth) fields.push({ name: 'QTH', value: qso.qth });
      if (qso.theirGrid) fields.push({ name: 'GRIDSQUARE', value: qso.theirGrid });
      if (qso.comment) fields.push({ name: 'COMMENT', value: qso.comment });

      return createRecord(fields);
    });

    const adif = exportADIF(records);
    const blob = new Blob([adif], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `hamstation-export-${new Date().toISOString().slice(0, 10)}.adi`;
    a.click();
    URL.revokeObjectURL(url);
  }

  return (
    <Button variant="ghost" size="sm" onClick={handleExport} title="Export ADIF">
      <Download size={14} /> Export
    </Button>
  );
}

/** Re-export createRecord for use in export. */
export { createRecord } from '@hamstation/shared/src/adif/parser';
