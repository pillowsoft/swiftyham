/** Amateur radio frequency bands with ranges in Hz. */
export const Band = {
  '160m': { label: '160m', lower: 1_800_000, upper: 2_000_000 },
  '80m': { label: '80m', lower: 3_500_000, upper: 4_000_000 },
  '60m': { label: '60m', lower: 5_330_500, upper: 5_405_000 },
  '40m': { label: '40m', lower: 7_000_000, upper: 7_300_000 },
  '30m': { label: '30m', lower: 10_100_000, upper: 10_150_000 },
  '20m': { label: '20m', lower: 14_000_000, upper: 14_350_000 },
  '17m': { label: '17m', lower: 18_068_000, upper: 18_168_000 },
  '15m': { label: '15m', lower: 21_000_000, upper: 21_450_000 },
  '12m': { label: '12m', lower: 24_890_000, upper: 24_990_000 },
  '10m': { label: '10m', lower: 28_000_000, upper: 29_700_000 },
  '6m': { label: '6m', lower: 50_000_000, upper: 54_000_000 },
  '2m': { label: '2m', lower: 144_000_000, upper: 148_000_000 },
  '70cm': { label: '70cm', lower: 420_000_000, upper: 450_000_000 },
  '23cm': { label: '23cm', lower: 1_240_000_000, upper: 1_300_000_000 },
} as const;

export type BandId = keyof typeof Band;
export const ALL_BANDS = Object.keys(Band) as BandId[];

/** Find the band for a given frequency in Hz. */
export function bandForFrequency(hz: number): BandId | null {
  for (const [id, range] of Object.entries(Band)) {
    if (hz >= range.lower && hz <= range.upper) return id as BandId;
  }
  return null;
}
