import type { BandId } from './band';
import type { OperatingMode } from './operating-mode';

export interface DXSpot {
  id: string;
  spotter: string;
  dxCallsign: string;
  frequency: number; // kHz
  comment?: string;
  timestamp: string; // ISO 8601
  band?: BandId;
  mode?: OperatingMode;
}
