/**
 * Bridge database hook — uses the Electrobun bridge's native SQLite
 * instead of sql.js WASM when running in the desktop app.
 */

import { useEffect, useState } from 'react';
import { BRIDGE_URL } from '@hamstation/shared/src/bridge/client';
import type { QSO, QSOFilter } from '@hamstation/shared';

export interface BridgeDatabaseContext {
  isReady: boolean;
  fetchQSOs: (filter?: Partial<QSOFilter>) => Promise<{ qsos: QSO[]; totalCount: number }>;
  insertQSO: (qso: QSO) => Promise<void>;
  deleteQSO: (id: string) => Promise<void>;
}

export function useBridgeDatabase(): BridgeDatabaseContext | null {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    // Check if bridge is available
    fetch(`${BRIDGE_URL}/api/health`, { signal: AbortSignal.timeout(2000) })
      .then(r => r.json())
      .then(data => {
        if (data.runtime === 'electrobun') {
          setReady(true);
          console.log('Using native SQLite via Electrobun bridge');
        }
      })
      .catch(() => {});
  }, []);

  if (!ready) return null;

  return {
    isReady: true,
    async fetchQSOs(filter) {
      const params = new URLSearchParams();
      if (filter?.limit) params.set('limit', String(filter.limit));
      if (filter?.offset) params.set('offset', String(filter.offset));
      if (filter?.band) params.set('band', filter.band);
      if (filter?.callsignContains) params.set('callsign', filter.callsignContains);

      const resp = await fetch(`${BRIDGE_URL}/api/qsos?${params}`);
      const data = await resp.json();

      // Map snake_case DB rows to camelCase QSO
      const qsos = data.qsos.map((row: any) => ({
        id: row.id,
        callsign: row.callsign,
        myCallsign: row.my_callsign,
        band: row.band,
        frequencyHz: row.frequency_hz,
        mode: row.mode,
        datetimeOn: row.datetime_on,
        datetimeOff: row.datetime_off,
        rstSent: row.rst_sent,
        rstReceived: row.rst_received,
        txPowerWatts: row.tx_power_watts,
        myGrid: row.my_grid,
        theirGrid: row.their_grid,
        name: row.name,
        qth: row.qth,
        comment: row.comment,
        logbookId: row.logbook_id,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      }));

      return { qsos, totalCount: data.totalCount };
    },
    async insertQSO(qso) {
      await fetch(`${BRIDGE_URL}/api/qsos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(qso),
      });
    },
    async deleteQSO(id) {
      await fetch(`${BRIDGE_URL}/api/qsos/${id}`, { method: 'DELETE' });
    },
  };
}
