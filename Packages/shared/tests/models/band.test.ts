import { describe, it, expect } from 'vitest';
import { Band, ALL_BANDS, bandForFrequency } from '../../src/models/band';

describe('Band', () => {
  it('has all expected bands', () => {
    expect(ALL_BANDS).toContain('20m');
    expect(ALL_BANDS).toContain('40m');
    expect(ALL_BANDS).toContain('10m');
    expect(ALL_BANDS.length).toBe(14);
  });

  it('bandForFrequency returns correct band', () => {
    expect(bandForFrequency(14_074_000)).toBe('20m');
    expect(bandForFrequency(7_074_000)).toBe('40m');
    expect(bandForFrequency(28_074_000)).toBe('10m');
    expect(bandForFrequency(3_573_000)).toBe('80m');
    expect(bandForFrequency(50_313_000)).toBe('6m');
  });

  it('bandForFrequency returns null for out-of-band', () => {
    expect(bandForFrequency(5_000_000)).toBeNull();
    expect(bandForFrequency(100)).toBeNull();
  });

  it('band ranges are valid', () => {
    for (const id of ALL_BANDS) {
      const band = Band[id];
      expect(band.lower).toBeLessThan(band.upper);
    }
  });
});
