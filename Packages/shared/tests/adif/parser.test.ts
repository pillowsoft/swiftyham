import { describe, it, expect } from 'vitest';
import { parseADIF, exportADIF, createRecord } from '../../src/adif/parser';

describe('ADIF Parser', () => {
  it('parses a simple QSO record', () => {
    const adif = '<CALL:4>W1AW <BAND:3>20m <MODE:3>SSB <RST_SENT:2>59 <RST_RCVD:2>59 <EOR>';
    const result = parseADIF(adif);
    expect(result.records).toHaveLength(1);
    expect(result.records[0].get('CALL')).toBe('W1AW');
    expect(result.records[0].get('BAND')).toBe('20m');
    expect(result.records[0].get('MODE')).toBe('SSB');
  });

  it('parses header and multiple records', () => {
    const adif = `
      <ADIF_VER:5>3.1.4
      <PROGRAMID:14>HamStation Pro
      <EOH>
      <CALL:5>JA1AB <BAND:3>20m <MODE:3>FT8 <EOR>
      <CALL:5>DL1AB <BAND:3>40m <MODE:2>CW <EOR>
    `;
    const result = parseADIF(adif);
    expect(result.header).toBeDefined();
    expect(result.header!.get('ADIF_VER')).toBe('3.1.4');
    expect(result.records).toHaveLength(2);
    expect(result.records[0].get('CALL')).toBe('JA1AB');
    expect(result.records[1].get('CALL')).toBe('DL1AB');
  });

  it('handles lenient mode with malformed tags', () => {
    const adif = '<CALL:4>W1AW <BAD> <MODE:3>SSB <EOR>';
    const result = parseADIF(adif, 'lenient');
    expect(result.records).toHaveLength(1);
    expect(result.warnings.length).toBeGreaterThan(0);
  });

  it('stops on error in strict mode', () => {
    const adif = '<CALL:4>W1AW <BAD> <MODE:3>SSB <EOR>';
    const result = parseADIF(adif, 'strict');
    expect(result.errors.length).toBeGreaterThan(0);
  });

  it('handles missing EOR at end of file', () => {
    const adif = '<CALL:4>W1AW <BAND:3>20m';
    const result = parseADIF(adif, 'lenient');
    expect(result.records).toHaveLength(1);
    expect(result.warnings.length).toBeGreaterThan(0);
  });

  it('handles empty input', () => {
    const result = parseADIF('');
    expect(result.records).toHaveLength(0);
    expect(result.errors).toHaveLength(0);
  });

  it('case-insensitive field names', () => {
    const adif = '<call:4>W1AW <Band:3>20m <EOR>';
    const result = parseADIF(adif);
    expect(result.records[0].get('CALL')).toBe('W1AW');
    expect(result.records[0].get('BAND')).toBe('20m');
  });
});

describe('ADIF Exporter', () => {
  it('exports records to ADIF format', () => {
    const records = [
      createRecord([
        { name: 'CALL', value: 'W1AW' },
        { name: 'BAND', value: '20m' },
        { name: 'MODE', value: 'SSB' },
      ]),
    ];
    const output = exportADIF(records);
    expect(output).toContain('ADIF_VER');
    expect(output).toContain('W1AW');
    expect(output).toContain('<EOR>');
  });

  it('round-trips parse → export → parse', () => {
    const original = '<CALL:4>W1AW <BAND:3>20m <MODE:3>FT8 <RST_SENT:3>-10 <EOR>';
    const parsed = parseADIF(original);
    const exported = exportADIF(parsed.records);
    const reparsed = parseADIF(exported);
    expect(reparsed.records).toHaveLength(1);
    expect(reparsed.records[0].get('CALL')).toBe('W1AW');
    expect(reparsed.records[0].get('MODE')).toBe('FT8');
  });
});
