export interface SolarData {
  solarFluxIndex: number;
  aIndex: number;
  kIndex: number;
  kIndexTrend: 'rising' | 'falling' | 'stable';
  xrayFlux: string;
  protonFlux?: number;
  updatedAt: string;
}

export type BandCondition = 'good' | 'fair' | 'poor';
export type KIndexSeverity = 'quiet' | 'unsettled' | 'storm' | 'severeStorm';

export function kIndexSeverity(k: number): KIndexSeverity {
  if (k <= 3) return 'quiet';
  if (k === 4) return 'unsettled';
  if (k === 5) return 'storm';
  return 'severeStorm';
}
