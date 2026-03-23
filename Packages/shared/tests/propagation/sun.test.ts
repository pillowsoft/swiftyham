import { describe, it, expect } from 'vitest';
import { solarTimes, greyLinePath } from '../../src/propagation/sun-calculator';

describe('SunCalculator', () => {
  it('computes sunrise/sunset for New York', () => {
    const date = new Date('2026-03-20T12:00:00Z');
    const times = solarTimes(40.7, -74.0, date);
    expect(times.sunrise).toBeDefined();
    expect(times.sunset).toBeDefined();
    expect(times.isPolarDay).toBe(false);
    expect(times.isPolarNight).toBe(false);
    if (times.sunrise && times.sunset) {
      expect(times.sunrise.getTime()).toBeLessThan(times.sunset.getTime());
    }
  });

  it('detects polar day in arctic summer', () => {
    const date = new Date('2026-06-21T12:00:00Z');
    const times = solarTimes(78.0, 15.0, date);
    expect(times.isPolarDay).toBe(true);
    expect(times.sunrise).toBeUndefined();
  });

  it('computes civil twilight', () => {
    const date = new Date('2026-03-20T12:00:00Z');
    const times = solarTimes(40.7, -74.0, date);
    expect(times.civilDawn).toBeDefined();
    expect(times.civilDusk).toBeDefined();
    if (times.civilDawn && times.sunrise) {
      expect(times.civilDawn.getTime()).toBeLessThan(times.sunrise.getTime());
    }
  });

  it('generates grey line path', () => {
    const path = greyLinePath();
    expect(path.length).toBeGreaterThan(100);
    for (const pt of path) {
      expect(pt.latitude).toBeGreaterThanOrEqual(-90);
      expect(pt.latitude).toBeLessThanOrEqual(90);
      expect(pt.longitude).toBeGreaterThanOrEqual(-180);
      expect(pt.longitude).toBeLessThanOrEqual(180);
    }
  });
});
