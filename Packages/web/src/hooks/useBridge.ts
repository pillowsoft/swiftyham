/**
 * Bridge auto-discovery hook.
 * Checks for bridge on localhost:8412 every 10 seconds.
 * Updates appStore.bridgeAvailable reactively.
 */

import { useEffect } from 'react';
import { appStore } from '@/stores/app';
import { checkBridgeHealth } from '@hamstation/shared/src/bridge/client';

export function useBridge() {
  useEffect(() => {
    let cancelled = false;

    async function check() {
      const health = await checkBridgeHealth();
      if (!cancelled) {
        appStore.bridgeAvailable = health !== null;
      }
    }

    // Check immediately
    check();

    // Re-check every 10 seconds
    const interval = setInterval(check, 10000);

    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, []);
}
