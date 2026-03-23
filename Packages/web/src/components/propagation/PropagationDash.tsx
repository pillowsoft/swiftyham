import { useEffect } from 'react';
import { useSnapshot } from 'valtio';
import { appStore } from '@/stores/app';
import { solarStore, fetchSolarData, bandConditions } from '@/stores/solar';
import { solarTimes } from '@hamstation/shared/src/propagation/sun-calculator';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import { ScrollArea } from '@/components/ui/scroll-area';
import { RefreshCw, Sunrise, Sunset, Sun, Moon } from 'lucide-react';
import type { BandCondition } from '@hamstation/shared';

const HF_BANDS = ['160m', '80m', '40m', '30m', '20m', '17m', '15m', '12m', '10m'];

export function PropagationDash() {
  const snap = useSnapshot(solarStore);

  useEffect(() => { if (!snap.data) fetchSolarData(); }, []);

  return (
    <ScrollArea className="flex-1">
      <div className="p-4 space-y-4">
        <div className="flex items-center gap-2">
          <h2 className="text-base font-semibold">Propagation</h2>
          <Button variant="ghost" size="icon" className="h-7 w-7" onClick={() => fetchSolarData()} title="Refresh">
            <RefreshCw size={14} className={snap.isLoading ? 'animate-spin' : ''} />
          </Button>
        </div>

        {snap.data ? (
          <>
            {/* Solar indices */}
            <div className="grid grid-cols-4 gap-2">
              <SolarCard label="SFI" value={snap.data.solarFluxIndex} color={snap.data.solarFluxIndex >= 100 ? 'text-[var(--green)]' : 'text-[var(--yellow)]'} />
              <SolarCard label="K-Index" value={snap.data.kIndex} color={snap.data.kIndex <= 3 ? 'text-[var(--green)]' : snap.data.kIndex <= 4 ? 'text-[var(--yellow)]' : 'text-[var(--red)]'} />
              <SolarCard label="A-Index" value={snap.data.aIndex} color={snap.data.aIndex <= 7 ? 'text-[var(--green)]' : 'text-[var(--yellow)]'} />
              <SolarCard label="X-Ray" value={snap.data.xrayFlux || '—'} color="text-[var(--blue)]" />
            </div>

            {/* Band conditions */}
            <div>
              <Label className="mb-2 block">Band Conditions</Label>
              <div className="grid grid-cols-3 gap-2">
                {HF_BANDS.map(band => {
                  const conditions = bandConditions(snap.data!);
                  return <BandCard key={band} band={band} condition={conditions[band] || 'poor'} />;
                })}
              </div>
            </div>

            {/* Sunrise/Sunset */}
            <SunTimesSection />

            <Separator />
            <p className="text-[11px] font-mono text-[var(--text-muted)]">
              Last updated: {new Date(snap.data.updatedAt).toLocaleTimeString()} UTC
            </p>
          </>
        ) : snap.isLoading ? (
          <div className="flex items-center justify-center py-20 text-[var(--text-muted)]">Loading solar data...</div>
        ) : snap.lastError ? (
          <div className="flex flex-col items-center justify-center py-20 text-[var(--text-muted)]">
            <p className="text-sm">Failed to load solar data</p>
            <p className="text-xs mt-1">{snap.lastError}</p>
            <Button variant="secondary" size="sm" className="mt-3" onClick={() => fetchSolarData()}>Retry</Button>
          </div>
        ) : null}
      </div>
    </ScrollArea>
  );
}

function SolarCard({ label, value, color }: { label: string; value: number | string; color: string }) {
  return (
    <Card>
      <CardContent className="p-3 text-center">
        <div className={`text-2xl font-bold font-mono ${color}`}>{value}</div>
        <Label className="mt-1 block">{label}</Label>
      </CardContent>
    </Card>
  );
}

function BandCard({ band, condition }: { band: string; condition: BandCondition }) {
  const variant = condition === 'good' ? 'green' : condition === 'fair' ? 'yellow' : 'red';
  return (
    <Card className="flex items-center justify-between px-3 py-2">
      <span className="text-sm font-bold font-mono">{band}</span>
      <Badge variant={variant}>{condition}</Badge>
    </Card>
  );
}

function SunTimesSection() {
  const snap = useSnapshot(appStore);
  const grid = snap.gridSquare || 'FN31';

  function gridToLL(g: string): [number, number] | null {
    if (g.length < 4) return null;
    const a = g.toUpperCase().charCodeAt(0) - 65, b = g.toUpperCase().charCodeAt(1) - 65;
    const c = parseInt(g[2]), d = parseInt(g[3]);
    if (isNaN(c) || isNaN(d)) return null;
    return [b * 10 + d + 0.5 - 90, a * 20 + c * 2 + 1 - 180];
  }

  const ll = gridToLL(grid);
  if (!ll) return null;
  const times = solarTimes(ll[0], ll[1]);
  const fmt = (d?: Date) => d ? d.toISOString().slice(11, 16) + ' UTC' : '—';

  return (
    <div>
      <Label className="mb-2 block">Sun Times — {grid.toUpperCase()}</Label>
      {times.isPolarDay ? <Badge variant="yellow">Polar Day — 24h daylight</Badge> :
       times.isPolarNight ? <Badge>Polar Night — 24h darkness</Badge> : (
        <div className="grid grid-cols-4 gap-2">
          <Card><CardContent className="p-2 flex items-center gap-1.5">
            <Sunrise size={14} className="text-[var(--yellow)]" />
            <div><Label>Sunrise</Label><div className="text-xs font-mono mt-0.5">{fmt(times.sunrise)}</div></div>
          </CardContent></Card>
          <Card><CardContent className="p-2 flex items-center gap-1.5">
            <Sunset size={14} className="text-[var(--red)]" />
            <div><Label>Sunset</Label><div className="text-xs font-mono mt-0.5">{fmt(times.sunset)}</div></div>
          </CardContent></Card>
          <Card><CardContent className="p-2 flex items-center gap-1.5">
            <Sun size={14} className="text-[var(--blue)]" />
            <div><Label>Dawn</Label><div className="text-xs font-mono mt-0.5">{fmt(times.civilDawn)}</div></div>
          </CardContent></Card>
          <Card><CardContent className="p-2 flex items-center gap-1.5">
            <Moon size={14} className="text-[var(--blue)]" />
            <div><Label>Dusk</Label><div className="text-xs font-mono mt-0.5">{fmt(times.civilDusk)}</div></div>
          </CardContent></Card>
        </div>
      )}
      <p className="text-[10px] mt-2 text-[var(--text-muted)]">
        {times.isDaytime ? '☀ Currently daytime' : '🌙 Currently nighttime'}
      </p>
    </div>
  );
}
