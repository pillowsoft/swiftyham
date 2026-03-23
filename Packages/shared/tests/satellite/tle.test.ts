import { describe, it, expect } from 'vitest';
import { parseTLE, DEMO_TLES } from '../../src/satellite/tle-parser';
import { propagate } from '../../src/satellite/sgp4';

describe('TLE Parser', () => {
  it('parses demo TLEs', () => {
    const tles = parseTLE(DEMO_TLES);
    expect(tles.length).toBe(3);
    expect(tles[0].name).toBe('ISS (ZARYA)');
    expect(tles[0].id).toBe(25544);
    expect(tles[0].inclination).toBeCloseTo(51.64, 1);
  });

  it('computes epoch date', () => {
    const tles = parseTLE(DEMO_TLES);
    const iss = tles[0];
    expect(iss.epochYear).toBe(2024);
    expect(iss.epoch.getFullYear()).toBe(2024);
  });
});

describe('SGP4 Propagator', () => {
  it('propagates ISS near epoch', () => {
    const tles = parseTLE(DEMO_TLES);
    const iss = tles[0];
    // Propagate 1 minute after epoch
    const testDate = new Date(iss.epoch.getTime() + 60000);
    const pos = propagate(iss, testDate);
    expect(pos).not.toBeNull();
    if (pos) {
      expect(pos.altitude).toBeGreaterThan(300);
      expect(pos.altitude).toBeLessThan(500);
      expect(pos.latitude).toBeGreaterThan(-60);
      expect(pos.latitude).toBeLessThan(60);
      expect(pos.velocity).toBeGreaterThan(6);
      expect(pos.velocity).toBeLessThan(9);
    }
  });
});
