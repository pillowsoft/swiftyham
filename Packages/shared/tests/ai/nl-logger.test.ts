import { describe, it, expect } from 'vitest';
import { parseNaturalLanguage } from '../../src/ai/natural-language-logger';

describe('Natural Language Logger', () => {
  it('parses full QSO description', () => {
    const result = parseNaturalLanguage('Worked JA1ABC on 20m FT8, -10 both ways');
    expect(result.callsign).toBe('JA1ABC');
    expect(result.band).toBe('20m');
    expect(result.mode).toBe('FT8');
    expect(result.rstSent).toBe('10');
    expect(result.rstReceived).toBe('10');
  });

  it('parses callsign only', () => {
    const result = parseNaturalLanguage('W1AW');
    expect(result.callsign).toBe('W1AW');
    expect(result.confidence).toBeGreaterThan(0);
  });

  it('parses band names', () => {
    expect(parseNaturalLanguage('on twenty meters').band).toBe('20m');
    expect(parseNaturalLanguage('on 40m').band).toBe('40m');
    expect(parseNaturalLanguage('on fifteen meters').band).toBe('15m');
  });

  it('parses mode keywords', () => {
    expect(parseNaturalLanguage('CW contact').mode).toBe('CW');
    expect(parseNaturalLanguage('on SSB').mode).toBe('SSB');
    expect(parseNaturalLanguage('FT8 decode').mode).toBe('FT8');
  });

  it('handles empty input', () => {
    const result = parseNaturalLanguage('');
    expect(result.confidence).toBe(0);
  });

  it('parses ON <number> band pattern', () => {
    const result = parseNaturalLanguage('Worked W1AW on 40 CW');
    expect(result.band).toBe('40m');
    expect(result.callsign).toBe('W1AW');
    expect(result.mode).toBe('CW');
  });
});
