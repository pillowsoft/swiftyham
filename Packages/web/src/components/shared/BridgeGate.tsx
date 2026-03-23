import { useSnapshot } from 'valtio';
import { appStore } from '@/stores/app';
import { Button } from '@/components/ui/button';
import { Download, Wifi } from 'lucide-react';

interface Props {
  feature: string;
  description: string;
  children: React.ReactNode;
}

/** Wraps bridge-dependent features. Shows download prompt if bridge is unavailable. */
export function BridgeGate({ feature, description, children }: Props) {
  const snap = useSnapshot(appStore);

  if (snap.bridgeAvailable) {
    return <>{children}</>;
  }

  return (
    <div className="flex-1 flex flex-col items-center justify-center p-8 gap-4">
      <div className="rounded-full p-4" style={{ background: 'var(--accent-dim)' }}>
        <Wifi size={32} style={{ color: 'var(--accent)' }} />
      </div>
      <h3 className="text-base font-semibold">{feature}</h3>
      <p className="text-sm text-center max-w-sm" style={{ color: 'var(--text-secondary)' }}>
        {description}
      </p>
      <p className="text-xs text-center max-w-sm" style={{ color: 'var(--text-muted)' }}>
        This feature requires the HamStation Bridge CLI running on your Mac.
        The bridge provides rig control, audio processing, and local AI inference.
      </p>
      <Button variant="secondary" size="sm">
        <Download size={14} /> Download Bridge CLI
      </Button>
    </div>
  );
}
