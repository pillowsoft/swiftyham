import { useState } from 'react';
import { useSnapshot } from 'valtio';
import { appStore } from '@/stores/app';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';

/** Convert 4-char grid to lat/lon. */
function gridToLatLon(grid: string): [number, number] | null {
  if (grid.length < 4) return null;
  const chars = grid.toUpperCase();
  const a = chars.charCodeAt(0) - 65;
  const b = chars.charCodeAt(1) - 65;
  const c = parseInt(chars[2]);
  const d = parseInt(chars[3]);
  if (isNaN(c) || isNaN(d) || a < 0 || a > 17 || b < 0 || b > 17) return null;
  const lon = a * 20 + c * 2 + 1 - 180;
  const lat = b * 10 + d * 1 + 0.5 - 90;
  return [lat, lon];
}

/** Azimuthal equidistant projection. */
function project(lat: number, lon: number, centerLat: number, centerLon: number, radius: number): [number, number] {
  const toRad = Math.PI / 180;
  const φ1 = centerLat * toRad, λ1 = centerLon * toRad;
  const φ2 = lat * toRad, λ2 = lon * toRad;

  const cosC = Math.sin(φ1) * Math.sin(φ2) + Math.cos(φ1) * Math.cos(φ2) * Math.cos(λ2 - λ1);
  const c = Math.acos(Math.max(-1, Math.min(1, cosC)));
  if (c === 0) return [0, 0];

  const k = c / Math.sin(c);
  const x = k * Math.cos(φ2) * Math.sin(λ2 - λ1);
  const y = k * (Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(λ2 - λ1));

  const scale = radius / Math.PI;
  return [x * scale, -y * scale];
}

/** Calculate bearing from center to target. */
function bearing(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = Math.PI / 180;
  const φ1 = lat1 * toRad, φ2 = lat2 * toRad;
  const Δλ = (lon2 - lon1) * toRad;
  const y = Math.sin(Δλ) * Math.cos(φ2);
  const x = Math.cos(φ1) * Math.sin(φ2) - Math.sin(φ1) * Math.cos(φ2) * Math.cos(Δλ);
  return ((Math.atan2(y, x) * 180 / Math.PI) + 360) % 360;
}

/** Great circle distance in km. */
function distance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = Math.PI / 180;
  const φ1 = lat1 * toRad, φ2 = lat2 * toRad;
  const Δφ = (lat2 - lat1) * toRad;
  const Δλ = (lon2 - lon1) * toRad;
  const a = Math.sin(Δφ / 2) ** 2 + Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

const COMPASS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

export function GreatCircleMap() {
  const snap = useSnapshot(appStore);
  const [targetGrid, setTargetGrid] = useState('');

  const center = gridToLatLon(snap.gridSquare || 'FN31') || [41.5, -72.5];
  const target = gridToLatLon(targetGrid);

  const size = 400;
  const cx = size / 2;
  const cy = size / 2;
  const mapRadius = size / 2 - 20;

  return (
    <div className="flex-1 flex overflow-hidden">
      {/* Map */}
      <div className="flex-1 flex items-center justify-center p-4">
        <svg viewBox={`0 0 ${size} ${size}`} width={size} height={size}>
          {/* Distance rings */}
          {[5000, 10000, 15000, 20000].map((km, i) => (
            <circle
              key={km}
              cx={cx} cy={cy}
              r={mapRadius * (i + 1) / 4}
              fill="none"
              stroke="var(--border)"
              strokeWidth={1}
            />
          ))}

          {/* Compass lines */}
          {[0, 45, 90, 135].map(deg => {
            const rad = deg * Math.PI / 180;
            return (
              <line key={deg}
                x1={cx + Math.sin(rad) * -mapRadius} y1={cy + Math.cos(rad) * -mapRadius}
                x2={cx + Math.sin(rad) * mapRadius} y2={cy + Math.cos(rad) * mapRadius}
                stroke="var(--border-subtle)" strokeWidth={1}
              />
            );
          })}

          {/* Compass labels */}
          {COMPASS.map((label, i) => {
            const deg = i * 45;
            const rad = deg * Math.PI / 180;
            const r = mapRadius + 12;
            return (
              <text key={label}
                x={cx + Math.sin(rad) * r} y={cy - Math.cos(rad) * r}
                textAnchor="middle" dominantBaseline="central"
                fill="var(--text-muted)" fontSize={9}
              >
                {label}
              </text>
            );
          })}

          {/* Distance labels */}
          {[5, 10, 15, 20].map((k, i) => (
            <text key={k}
              x={cx + 3} y={cy - mapRadius * (i + 1) / 4 + 3}
              fill="var(--text-muted)" fontSize={8}
            >
              {k}k
            </text>
          ))}

          {/* Center dot (QTH) */}
          <circle cx={cx} cy={cy} r={4} fill="var(--accent)" />

          {/* Target marker + line */}
          {target && (() => {
            const [px, py] = project(target[0], target[1], center[0], center[1], mapRadius);
            return (
              <>
                <line x1={cx} y1={cy} x2={cx + px} y2={cy + py} stroke="var(--accent)" strokeWidth={1.5} strokeDasharray="4 3" />
                <circle cx={cx + px} cy={cy + py} r={5} fill="var(--green)" />
                <text x={cx + px + 8} y={cy + py + 3} fill="var(--green)" fontSize={10} fontFamily="var(--font-mono)">
                  {targetGrid.toUpperCase()}
                </text>
              </>
            );
          })()}
        </svg>
      </div>

      {/* Right panel */}
      <div className="w-64 border-l p-4 overflow-y-auto" style={{ borderColor: 'var(--border)', background: 'var(--bg-surface)' }}>
        <h3 className="text-sm font-semibold mb-3">Heading Calculator</h3>

        <div className="mb-3">
          <label className="text-[10px] uppercase tracking-wider block mb-1" style={{ color: 'var(--text-muted)' }}>My Grid</label>
          <div className="font-mono text-sm" style={{ color: 'var(--accent)' }}>{snap.gridSquare || 'FN31'}</div>
        </div>

        <div className="mb-4">
          <label className="text-[10px] uppercase tracking-wider block mb-1" style={{ color: 'var(--text-muted)' }}>Target Grid</label>
          <Input
            className="font-mono uppercase"
            placeholder="PM95"
            value={targetGrid}
            onChange={(e) => setTargetGrid(e.target.value)}
          />
        </div>

        {target && (
          <>
            <Separator className="my-3" />
            <div className="space-y-2 text-xs">
              <DetailRow label="Bearing" value={`${bearing(center[0], center[1], target[0], target[1]).toFixed(1)}°`} />
              <DetailRow label="Distance" value={`${Math.round(distance(center[0], center[1], target[0], target[1])).toLocaleString()} km`} />
              <DetailRow label="Long Path" value={`${((bearing(center[0], center[1], target[0], target[1]) + 180) % 360).toFixed(1)}°`} />
            </div>
          </>
        )}

        <Separator className="my-4" />

        <h3 className="text-xs font-semibold mb-2" style={{ color: 'var(--text-muted)' }}>Reference Bearings</h3>
        <div className="space-y-1 text-xs">
          {[
            { grid: 'JO01', label: 'London' },
            { grid: 'PM95', label: 'Tokyo' },
            { grid: 'QF56', label: 'Sydney' },
            { grid: 'GG87', label: 'São Paulo' },
            { grid: 'KO85', label: 'Moscow' },
          ].map(ref => {
            const refLL = gridToLatLon(ref.grid);
            if (!refLL) return null;
            return (
              <div key={ref.grid} className="flex justify-between">
                <span style={{ color: 'var(--text-secondary)' }}>{ref.label}</span>
                <span className="font-mono">{bearing(center[0], center[1], refLL[0], refLL[1]).toFixed(0)}° / {Math.round(distance(center[0], center[1], refLL[0], refLL[1])).toLocaleString()} km</span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between">
      <span style={{ color: 'var(--text-muted)' }}>{label}</span>
      <span className="font-mono font-medium">{value}</span>
    </div>
  );
}
