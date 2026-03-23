import { useState, useEffect } from 'react';
import { useSnapshot } from 'valtio';
import { appStore } from '@/stores/app';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { parseTLE, DEMO_TLES } from '@hamstation/shared/src/satellite/tle-parser';
import { predictPasses, type SatellitePass } from '@hamstation/shared/src/satellite/pass-predictor';
import { RefreshCw } from 'lucide-react';

function gridToLatLon(grid: string): [number, number] | null {
  if (grid.length < 4) return null;
  const a = grid.toUpperCase().charCodeAt(0) - 65;
  const b = grid.toUpperCase().charCodeAt(1) - 65;
  const c = parseInt(grid[2]); const d = parseInt(grid[3]);
  if (isNaN(c) || isNaN(d)) return null;
  return [b * 10 + d + 0.5 - 90, a * 20 + c * 2 + 1 - 180];
}

function fmtDur(s: number): string { return `${Math.floor(s/60)}:${(s%60).toString().padStart(2,'0')}`; }
function fmtTime(d: Date): string { return d.toISOString().slice(11,16); }

export function SatelliteTracker() {
  const snap = useSnapshot(appStore);
  const [passes, setPasses] = useState<SatellitePass[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => { computePasses(); }, [snap.gridSquare]);

  function computePasses() {
    setIsLoading(true);
    const qth = gridToLatLon(snap.gridSquare || 'FN31') || [41.5, -72.5];
    const tles = parseTLE(DEMO_TLES);
    const all: SatellitePass[] = [];
    for (const tle of tles) {
      all.push(...predictPasses(tle, { latitude: qth[0], longitude: qth[1], altitude: 0 }, new Date(), 3, 5));
    }
    all.sort((a, b) => a.aos.getTime() - b.aos.getTime());
    setPasses(all);
    if (all.length > 0) setSelected(0);
    setIsLoading(false);
  }

  const sp = selected !== null ? passes[selected] : null;

  return (
    <div className="flex-1 flex overflow-hidden">
      <div className="w-80 border-r overflow-y-auto" style={{ borderColor: 'var(--border)' }}>
        <div className="p-3 flex items-center justify-between">
          <div>
            <h2 className="text-base font-semibold">Satellites</h2>
            <p className="text-xs" style={{ color: 'var(--text-muted)' }}>{passes.length} passes &bull; {snap.gridSquare || 'FN31'}</p>
          </div>
          <Button variant="ghost" size="icon" className="h-7 w-7" onClick={computePasses}>
            <RefreshCw size={14} className={isLoading ? 'animate-spin' : ''} />
          </Button>
        </div>
        {passes.map((p, i) => (
          <button key={i} onClick={() => setSelected(i)} className="w-full text-left px-3 py-2 cursor-pointer"
            style={{ background: selected === i ? 'var(--accent-dim)' : undefined, borderBottom: '1px solid var(--border-subtle)' }}>
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">{p.satellite}</span>
              <Badge variant={p.maxElevation >= 45 ? 'green' : p.maxElevation >= 20 ? 'yellow' : 'gray'}>{p.maxElevation}&deg;</Badge>
            </div>
            <div className="flex gap-3 mt-1 text-[11px] font-mono" style={{ color: 'var(--text-muted)' }}>
              <span>AOS {fmtTime(p.aos)}</span><span>LOS {fmtTime(p.los)}</span><span>{fmtDur(p.duration)}</span>
            </div>
          </button>
        ))}
        {passes.length === 0 && !isLoading && <p className="text-xs text-center py-8" style={{ color: 'var(--text-muted)' }}>No passes found</p>}
      </div>
      <div className="flex-1 p-4 overflow-y-auto">
        {sp ? (
          <>
            <h3 className="text-sm font-semibold mb-4">{sp.satellite}</h3>
            <div className="mx-auto mb-6" style={{ width: 240, height: 240 }}>
              <svg viewBox="0 0 240 240" className="w-full h-full">
                {[90,60,30,0].map(el => <circle key={el} cx={120} cy={120} r={(90-el)/90*100} fill="none" stroke="var(--border)" strokeWidth={1} />)}
                {[0,45,90,135].map(d => { const r=d*Math.PI/180; return <line key={d} x1={120+Math.sin(r)*-100} y1={120+Math.cos(r)*-100} x2={120+Math.sin(r)*100} y2={120+Math.cos(r)*100} stroke="var(--border-subtle)" strokeWidth={1} />; })}
                <text x={120} y={12} textAnchor="middle" fill="var(--text-muted)" fontSize={10}>N</text>
                <text x={228} y={124} textAnchor="middle" fill="var(--text-muted)" fontSize={10}>E</text>
                <text x={120} y={236} textAnchor="middle" fill="var(--text-muted)" fontSize={10}>S</text>
                <text x={12} y={124} textAnchor="middle" fill="var(--text-muted)" fontSize={10}>W</text>
                {(() => { const a=sp.aosAzimuth*Math.PI/180,l=sp.losAzimuth*Math.PI/180,hr=100,mr=(90-sp.maxElevation)/90*100;
                  return <path d={`M ${120+Math.sin(a)*hr} ${120-Math.cos(a)*hr} Q ${120+Math.sin((a+l)/2)*mr*0.5} ${120-Math.cos((a+l)/2)*mr*0.5} ${120+Math.sin(l)*hr} ${120-Math.cos(l)*hr}`} fill="none" stroke="var(--accent)" strokeWidth={2} />;
                })()}
              </svg>
            </div>
            <div className="grid grid-cols-2 gap-3 text-xs">
              <D label="AOS" value={fmtTime(sp.aos)+' UTC'} /><D label="LOS" value={fmtTime(sp.los)+' UTC'} />
              <D label="Max El" value={sp.maxElevation+'°'} /><D label="Duration" value={fmtDur(sp.duration)} />
              <D label="AOS Az" value={sp.aosAzimuth+'°'} /><D label="LOS Az" value={sp.losAzimuth+'°'} />
            </div>
          </>
        ) : <div className="flex items-center justify-center h-full" style={{ color: 'var(--text-muted)' }}>{isLoading ? 'Computing...' : 'Select a pass'}</div>}
      </div>
    </div>
  );
}

function D({ label, value }: { label: string; value: string }) {
  return <div><div className="text-[10px] uppercase tracking-wider" style={{ color: 'var(--text-muted)' }}>{label}</div><div className="font-mono mt-0.5">{value}</div></div>;
}
