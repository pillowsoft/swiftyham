import { BridgeGate } from '@/components/shared/BridgeGate';

export function FT8Panel() {
  return (
    <BridgeGate
      feature="FT8 Digital Mode"
      description="Decode and transmit FT8/FT4 signals with real-time waterfall display. Requires audio input from your radio via the bridge."
    >
      <div>FT8 decoder view</div>
    </BridgeGate>
  );
}
