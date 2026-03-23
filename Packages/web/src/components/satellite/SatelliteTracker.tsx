import { useState } from 'react';
import { Badge } from '@/components/ui/badge';

interface SatPass {
  id: string;
  name: string;
  aos: string;
  los: string;
  maxEl: number;
  aosAz: number;
  losAz: number;
  duration: string;
}

const DEMO_PASSES: SatPass[] = [
  { id: '1', name: 'ISS (ZARYA)', aos: '14:32', los: '14:42', maxEl: 67, aosAz: 215, losAz: 45, duration: '10:12' },
  { id: '2', name: 'SO-50', aos: '15:18', los: '15:30', maxEl: 34, aosAz: 310, losAz: 120, duration: '12:05' },
  { id: '3', name: 'AO-91', aos: '16:45', los: '16:55', maxEl: 22, aosAz: 180, losAz: 350, duration: '10:30' },
  { id: '4', name: 'ISS (ZARYA)', aos: '19:05', los: '19:16', maxEl: 82, aosAz: 290, losAz: 75, duration: '11:00' },
  { id: '5', name: 'FO-29', aos: '20:12', los: '20:24', maxEl: 45, aosAz: 155, losAz: 20, duration: '12:15' },
];

export function SatelliteTracker() {
  const [selected, setSelected] = useState<string | null>('1');

  const selectedPass = DEMO_PASSES.find(p => p.id === selected);

  return (
    <div className="flex-1 flex overflow-hidden">
      {/* Pass list */}
      <div className="w-80 border-r overflow-y-auto" style={{ borderColor: 'var(--border)' }}>
        <div className="p-3">
          <h2 className="text-base font-semibold mb-3">Satellites</h2>
          <p className="text-xs mb-3" style={{ color: 'var(--text-muted)' }}>Upcoming passes for your QTH</p>
        </div>
        {DEMO_PASSES.map(pass => (
          <button
            key={pass.id}
            onClick={() => setSelected(pass.id)}
            className="w-full text-left px-3 py-2 cursor-pointer transition-colors"
            style={{
              background: selected === pass.id ? 'var(--accent-dim)' : undefined,
              borderBottom: '1px solid var(--border-subtle)',
            }}
          >
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">{pass.name}</span>
              <Badge variant={pass.maxEl >= 45 ? 'green' : pass.maxEl >= 20 ? 'yellow' : 'gray'}>
                {pass.maxEl}°
              </Badge>
            </div>
            <div className="flex gap-3 mt-1 text-[11px] font-mono" style={{ color: 'var(--text-muted)' }}>
              <span>AOS {pass.aos}</span>
              <span>LOS {pass.los}</span>
              <span>{pass.duration}</span>
            </div>
          </button>
        ))}
      </div>

      {/* Detail + polar plot */}
      <div className="flex-1 p-4 overflow-y-auto">
        {selectedPass ? (
          <>
            <h3 className="text-sm font-semibold mb-4">{selectedPass.name}</h3>

            {/* Polar plot placeholder */}
            <div className="mx-auto mb-6" style={{ width: 240, height: 240 }}>
              <svg viewBox="0 0 240 240" className="w-full h-full">
                {/* Elevation rings */}
                {[90, 60, 30, 0].map(el => (
                  <circle
                    key={el}
                    cx={120} cy={120}
                    r={(90 - el) / 90 * 100}
                    fill="none"
                    stroke="var(--border)"
                    strokeWidth={1}
                  />
                ))}
                {/* Compass lines */}
                {[0, 45, 90, 135].map(deg => {
                  const rad = deg * Math.PI / 180;
                  return (
                    <line
                      key={deg}
                      x1={120 + Math.sin(rad) * -100} y1={120 + Math.cos(rad) * -100}
                      x2={120 + Math.sin(rad) * 100} y2={120 + Math.cos(rad) * 100}
                      stroke="var(--border-subtle)" strokeWidth={1}
                    />
                  );
                })}
                {/* Compass labels */}
                <text x={120} y={12} textAnchor="middle" fill="var(--text-muted)" fontSize={10}>N</text>
                <text x={228} y={124} textAnchor="middle" fill="var(--text-muted)" fontSize={10}>E</text>
                <text x={120} y={236} textAnchor="middle" fill="var(--text-muted)" fontSize={10}>S</text>
                <text x={12} y={124} textAnchor="middle" fill="var(--text-muted)" fontSize={10}>W</text>
                {/* Pass arc (simplified) */}
                <path
                  d={`M ${120 + Math.sin(selectedPass.aosAz * Math.PI / 180) * 95} ${120 - Math.cos(selectedPass.aosAz * Math.PI / 180) * 95} Q 120 ${120 - selectedPass.maxEl} ${120 + Math.sin(selectedPass.losAz * Math.PI / 180) * 95} ${120 - Math.cos(selectedPass.losAz * Math.PI / 180) * 95}`}
                  fill="none" stroke="var(--accent)" strokeWidth={2}
                />
              </svg>
            </div>

            {/* Pass details */}
            <div className="grid grid-cols-2 gap-3 text-xs">
              <DetailRow label="AOS Time" value={selectedPass.aos + ' UTC'} />
              <DetailRow label="LOS Time" value={selectedPass.los + ' UTC'} />
              <DetailRow label="Max Elevation" value={selectedPass.maxEl + '°'} />
              <DetailRow label="Duration" value={selectedPass.duration} />
              <DetailRow label="AOS Azimuth" value={selectedPass.aosAz + '°'} />
              <DetailRow label="LOS Azimuth" value={selectedPass.losAz + '°'} />
            </div>
          </>
        ) : (
          <div className="flex items-center justify-center h-full" style={{ color: 'var(--text-muted)' }}>
            Select a pass to see details
          </div>
        )}
      </div>
    </div>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider" style={{ color: 'var(--text-muted)' }}>{label}</div>
      <div className="font-mono mt-0.5">{value}</div>
    </div>
  );
}
