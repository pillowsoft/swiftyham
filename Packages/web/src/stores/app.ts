import { proxy } from 'valtio';

export type SidebarSection =
  | 'logbook' | 'dxCluster' | 'bandMap' | 'globe' | 'awards'
  | 'sotaPota' | 'propagation' | 'repeaters' | 'cwTraining'
  | 'satellite' | 'ft8' | 'aiAssistant' | 'audioSpectrum'
  | 'greatCircleMap' | 'contest' | 'tools';

export type Theme = 'dark' | 'light' | 'night';

export interface SidebarItem {
  id: SidebarSection;
  label: string;
  icon: string; // Lucide icon name
  bridgeRequired?: boolean;
}

export const SIDEBAR_ITEMS: SidebarItem[] = [
  { id: 'logbook', label: 'Logbook', icon: 'book-open' },
  { id: 'dxCluster', label: 'DX Cluster', icon: 'globe', bridgeRequired: true },
  { id: 'bandMap', label: 'Band Map', icon: 'activity' },
  { id: 'globe', label: 'Globe', icon: 'earth' },
  { id: 'awards', label: 'Awards', icon: 'medal' },
  { id: 'sotaPota', label: 'SOTA / POTA', icon: 'mountain' },
  { id: 'propagation', label: 'Propagation', icon: 'sun' },
  { id: 'contest', label: 'Contest', icon: 'timer' },
  { id: 'repeaters', label: 'Repeaters', icon: 'radio' },
  { id: 'cwTraining', label: 'CW Training', icon: 'audio-waveform' },
  { id: 'satellite', label: 'Satellites', icon: 'satellite' },
  { id: 'ft8', label: 'FT8', icon: 'waves', bridgeRequired: true },
  { id: 'aiAssistant', label: 'AI Assistant', icon: 'brain' },
  { id: 'audioSpectrum', label: 'Spectrum', icon: 'bar-chart-3', bridgeRequired: true },
  { id: 'greatCircleMap', label: 'Great Circle', icon: 'map' },
  { id: 'tools', label: 'Tools', icon: 'wrench' },
];

export const appStore = proxy({
  // Navigation
  selectedSection: 'logbook' as SidebarSection,
  selectedQSOId: null as string | null,
  showInspector: true,
  showSettings: false,

  // Theme
  theme: (localStorage.getItem('hamstation-theme') || 'dark') as Theme,

  // User profile
  operatorCallsign: localStorage.getItem('hamstation-callsign') || '',
  operatorName: localStorage.getItem('hamstation-name') || '',
  gridSquare: localStorage.getItem('hamstation-grid') || '',
  licenseClass: localStorage.getItem('hamstation-license') || 'Extra',

  // Onboarding
  hasCompletedOnboarding: localStorage.getItem('hamstation-onboarded') === 'true',

  // Bridge
  bridgeAvailable: false,
});

export function setTheme(theme: Theme) {
  appStore.theme = theme;
  localStorage.setItem('hamstation-theme', theme);
  document.documentElement.className = theme;
}

export function saveProfile() {
  localStorage.setItem('hamstation-callsign', appStore.operatorCallsign);
  localStorage.setItem('hamstation-name', appStore.operatorName);
  localStorage.setItem('hamstation-grid', appStore.gridSquare);
  localStorage.setItem('hamstation-license', appStore.licenseClass);
}

export function completeOnboarding() {
  appStore.hasCompletedOnboarding = true;
  localStorage.setItem('hamstation-onboarded', 'true');
  saveProfile();
}
