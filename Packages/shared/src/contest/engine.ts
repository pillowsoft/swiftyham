/**
 * Contest engine — dupe checking, scoring, built-in definitions.
 * Port of HamStationKit/Sources/Contest/ContestEngine.swift
 */

export interface ContestDefinition {
  id: string;
  name: string;
  sponsor: string;
  modes: string[];
  bands: string[];
  exchangeSent: ExchangeType;
  exchangeReceived: ExchangeType;
  dupeRule: DupeRule;
  scoringFormula: ScoringFormula;
  multiplierType: MultiplierType;
  pointsPerQSO: number;
}

export type ExchangeType = 'rstSerial' | 'rstZone' | 'rstState' | 'rstPower' | 'gridSquare' | 'custom';
export type DupeRule = 'oncePerBand' | 'oncePerBandMode' | 'oncePerContest';
export type ScoringFormula = 'pointsTimesMults' | 'pointsOnly';
export type MultiplierType = 'zonePerBand' | 'dxccPerBand' | 'dxccPerMode' | 'statePerBand' | 'gridPerBand' | 'none';

export interface ContestQSO {
  id: string;
  callsign: string;
  band: string;
  mode: string;
  exchangeSent: string;
  exchangeReceived: string;
  timestamp: Date;
  isDupe: boolean;
  points: number;
  isMultiplier: boolean;
}

export interface ContestScore {
  totalQSOs: number;
  validQSOs: number;
  points: number;
  multipliers: number;
  score: number;
  dupes: number;
}

export class ContestEngine {
  readonly definition: ContestDefinition;
  qsos: ContestQSO[] = [];
  serialNumber = 1;
  private workedSet = new Set<string>();
  private multiplierSet = new Set<string>();

  constructor(definition: ContestDefinition) {
    this.definition = definition;
  }

  logQSO(callsign: string, exchange: string, band: string, mode: string): ContestQSO {
    const upper = callsign.toUpperCase();
    const dupe = this.isDupe(upper, band, mode);
    const points = dupe ? 0 : this.definition.pointsPerQSO;

    const exchangeSent = this.definition.exchangeSent === 'rstSerial'
      ? `599 ${String(this.serialNumber).padStart(3, '0')}`
      : '599 05';

    const qso: ContestQSO = {
      id: crypto.randomUUID(),
      callsign: upper, band, mode,
      exchangeSent, exchangeReceived: exchange,
      timestamp: new Date(), isDupe: dupe, points,
      isMultiplier: false,
    };

    this.qsos.push(qso);
    if (!dupe) {
      this.workedSet.add(this.dupeKey(upper, band, mode));
      this.serialNumber++;
    }

    return qso;
  }

  isDupe(callsign: string, band: string, mode: string): boolean {
    return this.workedSet.has(this.dupeKey(callsign.toUpperCase(), band, mode));
  }

  get score(): ContestScore {
    const valid = this.qsos.filter(q => !q.isDupe);
    const points = valid.reduce((s, q) => s + q.points, 0);
    const mults = Math.max(1, this.multiplierSet.size);
    return {
      totalQSOs: this.qsos.length,
      validQSOs: valid.length,
      points,
      multipliers: mults,
      score: this.definition.scoringFormula === 'pointsTimesMults' ? points * mults : points,
      dupes: this.qsos.length - valid.length,
    };
  }

  private dupeKey(call: string, band: string, mode: string): string {
    switch (this.definition.dupeRule) {
      case 'oncePerBandMode': return `${call}|${band}|${mode}`;
      case 'oncePerBand': return `${call}|${band}`;
      case 'oncePerContest': return call;
    }
  }

  /** Export to Cabrillo 3.0 format. */
  exportCabrillo(operatorCallsign: string, category: string, power: string): string {
    const lines: string[] = [];
    lines.push('START-OF-LOG: 3.0');
    lines.push(`CONTEST: ${this.definition.id}`);
    lines.push(`CALLSIGN: ${operatorCallsign}`);
    lines.push(`CATEGORY-OPERATOR: ${category}`);
    lines.push(`CATEGORY-POWER: ${power}`);
    lines.push(`CLAIMED-SCORE: ${this.score.score}`);
    lines.push('CREATED-BY: HamStation Pro Web 0.1.0');

    for (const qso of this.qsos.filter(q => !q.isDupe)) {
      const freq = bandToFreqKHz(qso.band);
      const mode = qso.mode === 'CW' ? 'CW' : qso.mode === 'SSB' ? 'PH' : 'RY';
      const date = qso.timestamp.toISOString().slice(0, 10);
      const time = qso.timestamp.toISOString().slice(11, 15).replace(':', '');
      lines.push(`QSO: ${String(freq).padStart(5)} ${mode.padEnd(2)} ${date} ${time} ${operatorCallsign.padEnd(13)} ${qso.exchangeSent.padEnd(6)} ${qso.callsign.padEnd(13)} ${qso.exchangeReceived}`);
    }

    lines.push('END-OF-LOG:');
    return lines.join('\n') + '\n';
  }
}

function bandToFreqKHz(band: string): number {
  const map: Record<string, number> = { '160m': 1800, '80m': 3500, '40m': 7000, '20m': 14000, '15m': 21000, '10m': 28000, '6m': 50000 };
  return map[band] || 14000;
}

// Built-in contest definitions
export const BUILT_IN_CONTESTS: ContestDefinition[] = [
  { id: 'CQWW-CW', name: 'CQ WW CW', sponsor: 'CQ Magazine', modes: ['CW'], bands: ['160m','80m','40m','20m','15m','10m'], exchangeSent: 'rstZone', exchangeReceived: 'rstZone', dupeRule: 'oncePerBand', scoringFormula: 'pointsTimesMults', multiplierType: 'zonePerBand', pointsPerQSO: 3 },
  { id: 'CQWW-SSB', name: 'CQ WW SSB', sponsor: 'CQ Magazine', modes: ['SSB'], bands: ['160m','80m','40m','20m','15m','10m'], exchangeSent: 'rstZone', exchangeReceived: 'rstZone', dupeRule: 'oncePerBand', scoringFormula: 'pointsTimesMults', multiplierType: 'zonePerBand', pointsPerQSO: 3 },
  { id: 'ARRL-DX-CW', name: 'ARRL DX CW', sponsor: 'ARRL', modes: ['CW'], bands: ['160m','80m','40m','20m','15m','10m'], exchangeSent: 'rstPower', exchangeReceived: 'rstPower', dupeRule: 'oncePerBand', scoringFormula: 'pointsTimesMults', multiplierType: 'dxccPerBand', pointsPerQSO: 3 },
  { id: 'NAQP-CW', name: 'NAQP CW', sponsor: 'NCJ', modes: ['CW'], bands: ['160m','80m','40m','20m','15m','10m'], exchangeSent: 'rstState', exchangeReceived: 'rstState', dupeRule: 'oncePerBand', scoringFormula: 'pointsOnly', multiplierType: 'statePerBand', pointsPerQSO: 1 },
  { id: 'WPX-CW', name: 'CQ WPX CW', sponsor: 'CQ Magazine', modes: ['CW'], bands: ['160m','80m','40m','20m','15m','10m'], exchangeSent: 'rstSerial', exchangeReceived: 'rstSerial', dupeRule: 'oncePerBand', scoringFormula: 'pointsTimesMults', multiplierType: 'none', pointsPerQSO: 3 },
];
