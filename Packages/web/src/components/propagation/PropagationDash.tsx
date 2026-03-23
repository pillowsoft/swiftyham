import { useEffect } from 'react';
import { useSnapshot } from 'valtio';
import { solarStore, fetchSolarData, bandConditions } from '@/stores/solar';
import { RefreshCw } from 'lucide-react';
import type { BandCondition } from '@hamstation/shared';

const HF_BANDS = ['160m', '80m', '40m', '30m', '20m', '17m', '15m', '12m', '10m'];

export function PropagationDash() {
  const snap = useSnapshot(solarStore);

  useEffect(() => {
    if (!snap.data) fetchSolarData();
  }, []);

  return (
    <div className="flex-1 overflow-auto p-4">
      {/* Solar indices */}
      <div className="flex items-center gap-2 mb-4">
        <h2 className="text-base font-semibold">Propagation</h2>
        <button
          onClick={() => fetchSolarData()}
          className="p-1 rounded cursor-pointer"
          style={{ color: 'var(--text-muted)' }}
          title="Refresh"
        >
          <RefreshCw size={14} className={snap.isLoading ? 'animate-spin' : ''} />
        </button>
      </div>

      {snap.data ? (
        <>
          {/* Index cards */}
          <div className="grid grid-cols-4 gap-2 mb-6">
            <SolarCard label="SFI" value={snap.data.solarFluxIndex} color={snap.data.solarFluxIndex >= 100 ? 'var(--green)' : 'var(--yellow)'} />
            <SolarCard label="K-Index" value={snap.data.kIndex} color={snap.data.kIndex <= 3 ? 'var(--green)' : snap.data.kIndex <= 4 ? 'var(--yellow)' : 'var(--red)'} />
            <SolarCard label="A-Index" value={snap.data.aIndex} color={snap.data.aIndex <= 7 ? 'var(--green)' : 'var(--yellow)'} />
            <SolarCard label="X-Ray" value={snap.data.xrayFlux || '—'} color="var(--blue)" />
          </div>

          {/* Band conditions grid */}
          <h3 className="text-xs font-semibold uppercase tracking-wider mb-2" style={{ color: 'var(--text-muted)' }}>
            Band Conditions
          </h3>
          <div className="grid grid-cols-3 gap-2 mb-6">
            {HF_BANDS.map(band => {
              const conditions = bandConditions(snap.data!);
              const condition = conditions[band] || 'poor';
              return <BandCard key={band} band={band} condition={condition} />;
            })}
          </div>

          {/* Last updated */}
          <p className="text-[11px]" style={{ color: 'var(--text-muted)', fontFamily: 'var(--font-mono)' }}>
            Last updated: {new Date(snap.data.updatedAt).toLocaleTimeString()} UTC
          </p>
        </>
      ) : snap.isLoading ? (
        <div className="flex items-center justify-center py-20" style={{ color: 'var(--text-muted)' }}>
          Loading solar data...
        </div>
      ) : snap.lastError ? (
        <div className="flex flex-col items-center justify-center py-20" style={{ color: 'var(--text-muted)' }}>
          <p className="text-sm">Failed to load solar data</p>
          <p className="text-xs mt-1">{snap.lastError}</p>
          <button
            onClick={() => fetchSolarData()}
            className="mt-3 px-3 py-1 rounded text-xs cursor-pointer"
            style={{ border: '1px solid var(--border)', color: 'var(--text-secondary)' }}
          >
            Retry
          </button>
        </div>
      ) : null}
    </div>
  );
}

function SolarCard({ label, value, color }: { label: string; value: number | string; color: string }) {
  return (
    <div
      className="text-center rounded-md p-3"
      style={{ border: '1px solid var(--border)', background: 'var(--bg-surface)' }}
    >
      <div className="text-2xl font-bold" style={{ fontFamily: 'var(--font-mono)', color }}>
        {value}
      </div>
      <div className="text-[10px] uppercase tracking-wider mt-1" style={{ color: 'var(--text-muted)' }}>
        {label}
      </div>
    </div>
  );
}

function BandCard({ band, condition }: { band: string; condition: BandCondition }) {
  const color = condition === 'good' ? 'var(--green)' : condition === 'fair' ? 'var(--yellow)' : 'var(--red)';
  return (
    <div
      className="flex items-center justify-between rounded px-3 py-2"
      style={{ border: '1px solid var(--border)', background: `color-mix(in srgb, ${color} 5%, var(--bg-surface))` }}
    >
      <span className="text-sm font-bold" style={{ fontFamily: 'var(--font-mono)' }}>{band}</span>
      <span className="text-[11px] font-medium capitalize" style={{ color }}>
        {condition}
      </span>
    </div>
  );
}
