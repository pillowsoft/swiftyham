/** Operating modes supported by the app. */
export type OperatingMode =
  | 'SSB' | 'LSB' | 'USB' | 'AM' | 'FM' | 'CW'
  | 'RTTY' | 'PSK31' | 'PSK63' | 'FT8' | 'FT4'
  | 'JS8' | 'WSPR' | 'JT65' | 'JT9'
  | 'SSTV' | 'FAX' | 'OLIVIA' | 'CONTESTIA' | 'THOR'
  | 'DSTAR' | 'DMR' | 'C4FM' | 'P25' | 'SAT';

export const ALL_MODES: OperatingMode[] = [
  'SSB', 'LSB', 'USB', 'AM', 'FM', 'CW',
  'RTTY', 'PSK31', 'PSK63', 'FT8', 'FT4',
  'JS8', 'WSPR', 'JT65', 'JT9',
  'SSTV', 'FAX', 'OLIVIA', 'CONTESTIA', 'THOR',
  'DSTAR', 'DMR', 'C4FM', 'P25', 'SAT',
];

export function isDigitalMode(mode: OperatingMode): boolean {
  return ['FT8', 'FT4', 'JS8', 'WSPR', 'JT65', 'JT9', 'PSK31', 'PSK63',
    'RTTY', 'OLIVIA', 'CONTESTIA', 'THOR', 'SSTV'].includes(mode);
}

export function defaultRST(mode: OperatingMode): string {
  if (isDigitalMode(mode)) return '-10';
  if (mode === 'CW') return '599';
  return '59';
}
