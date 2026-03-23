/**
 * Bridge client — auto-discovers and communicates with the HamStation Bridge CLI.
 */

export const BRIDGE_URL = 'http://127.0.0.1:8412';

export interface BridgeHealth {
  status: string;
  version: string;
  capabilities: string[];
}

export interface BridgeSystemInfo {
  totalGB: number;
}

/**
 * Check if the bridge is available.
 */
export async function checkBridgeHealth(): Promise<BridgeHealth | null> {
  try {
    const resp = await fetch(`${BRIDGE_URL}/api/health`, {
      signal: AbortSignal.timeout(2000),
    });
    if (!resp.ok) return null;
    return await resp.json();
  } catch {
    return null;
  }
}

/**
 * Get system RAM info from bridge.
 */
export async function getSystemInfo(): Promise<BridgeSystemInfo | null> {
  try {
    const resp = await fetch(`${BRIDGE_URL}/api/system/ram`, {
      signal: AbortSignal.timeout(2000),
    });
    if (!resp.ok) return null;
    return await resp.json();
  } catch {
    return null;
  }
}

/**
 * Get available LLM models from bridge.
 */
export async function getLLMModels(): Promise<any[]> {
  try {
    const resp = await fetch(`${BRIDGE_URL}/api/llm/models`, {
      signal: AbortSignal.timeout(5000),
    });
    if (!resp.ok) return [];
    return await resp.json();
  } catch {
    return [];
  }
}

/**
 * Get NTP sync status from bridge.
 */
export async function getNTPStatus(): Promise<any | null> {
  try {
    const resp = await fetch(`${BRIDGE_URL}/api/ntp/status`, {
      signal: AbortSignal.timeout(2000),
    });
    if (!resp.ok) return null;
    return await resp.json();
  } catch {
    return null;
  }
}
