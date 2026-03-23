import { BridgeGate } from '@/components/shared/BridgeGate';

export function DXClusterPanel() {
  return (
    <BridgeGate
      feature="DX Cluster"
      description="Connect to DX cluster servers to see real-time spots from operators worldwide. Color-coded by award status (needed, worked, confirmed)."
    >
      <div>DX Cluster connected view</div>
    </BridgeGate>
  );
}
