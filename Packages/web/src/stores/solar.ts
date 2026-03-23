import { proxy } from 'valtio';
import type { SolarData, BandCondition } from '@hamstation/shared';

export const solarStore = proxy({
  data: null as SolarData | null,
  isLoading: false,
  lastError: null as string | null,
});

const NOAA_SFI = 'https://services.swpc.noaa.gov/json/f107_cm_flux.json';
const NOAA_KINDEX = 'https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json';

export async function fetchSolarData() {
  solarStore.isLoading = true;
  solarStore.lastError = null;

  try {
    const [sfiRes, kRes] = await Promise.all([fetch(NOAA_SFI), fetch(NOAA_KINDEX)]);
    const sfiData = await sfiRes.json();
    const kData = await kRes.json();

    const sfi = Math.round(sfiData[sfiData.length - 1]?.flux ?? 0);
    const lastK = kData[kData.length - 1];
    const kIndex = Math.round(parseFloat(lastK?.[1] ?? '0'));
    const aIndex = Math.round(parseFloat(lastK?.[3] ?? '0'));

    solarStore.data = {
      solarFluxIndex: sfi,
      aIndex,
      kIndex,
      kIndexTrend: 'stable',
      xrayFlux: '',
      updatedAt: new Date().toISOString(),
    };
  } catch (err) {
    solarStore.lastError = (err as Error).message;
  }
  solarStore.isLoading = false;
}

const HF_BANDS = ['160m', '80m', '40m', '30m', '20m', '17m', '15m', '12m', '10m'] as const;

export function bandConditions(data: SolarData): Record<string, BandCondition> {
  const { solarFluxIndex: sfi, kIndex: k } = data;
  const result: Record<string, BandCondition> = {};
  for (const band of HF_BANDS) {
    if (k >= 5) { result[band] = ['160m','80m','40m'].includes(band) ? 'fair' : 'poor'; continue; }
    switch (band) {
      case '10m': result[band] = sfi >= 150 && k <= 2 ? 'good' : sfi >= 100 ? 'fair' : 'poor'; break;
      case '12m': result[band] = sfi >= 130 && k <= 2 ? 'good' : sfi >= 90 ? 'fair' : 'poor'; break;
      case '15m': result[band] = sfi >= 100 && k <= 3 ? 'good' : sfi >= 80 ? 'fair' : 'poor'; break;
      case '17m': result[band] = sfi >= 90 && k <= 3 ? 'good' : sfi >= 70 ? 'fair' : 'poor'; break;
      case '20m': case '30m': case '40m': result[band] = k <= 3 ? 'good' : 'fair'; break;
      case '80m': result[band] = k <= 2 ? 'good' : 'fair'; break;
      case '160m': result[band] = k <= 1 ? 'good' : k <= 3 ? 'fair' : 'poor'; break;
    }
  }
  return result;
}
