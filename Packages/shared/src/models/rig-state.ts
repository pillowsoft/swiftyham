import type { OperatingMode } from './operating-mode';

export type ConnectionState = 'disconnected' | 'connecting' | 'connected' | 'reconnecting' | 'error';

export interface RigState {
  frequency: number;
  mode: OperatingMode;
  pttActive: boolean;
  signalStrength?: number;
}
