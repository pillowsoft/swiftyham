import { appStore, type SidebarSection } from '@/stores/app';
import { AudioWaveform, Calculator, Satellite, BarChart3, Map } from 'lucide-react';

interface ToolCard {
  id: SidebarSection;
  icon: React.ElementType;
  title: string;
  description: string;
}

const TOOLS: ToolCard[] = [
  { id: 'cwTraining', icon: AudioWaveform, title: 'CW Training', description: 'Koch trainer, callsign practice, QSO simulator' },
  { id: 'satellite', icon: Satellite, title: 'Satellite Tracker', description: 'Pass predictions, Doppler correction, polar plot' },
  { id: 'audioSpectrum', icon: BarChart3, title: 'Audio Spectrum', description: 'Real-time FFT analyzer and waterfall display' },
  { id: 'greatCircleMap', icon: Map, title: 'Great Circle Map', description: 'Azimuthal equidistant projection with beam headings' },
];

export function ToolsPanel() {
  return (
    <div className="flex-1 overflow-auto p-4">
      <h2 className="text-base font-semibold mb-4">Tools</h2>
      <div className="grid grid-cols-2 gap-3">
        {TOOLS.map(tool => (
          <button
            key={tool.id}
            onClick={() => { appStore.selectedSection = tool.id; }}
            className="flex items-start gap-3 rounded-md p-3 text-left cursor-pointer transition-colors"
            style={{ border: '1px solid var(--border)', background: 'var(--bg-surface)' }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLElement).style.background = 'var(--bg-tertiary)'; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLElement).style.background = 'var(--bg-surface)'; }}
          >
            <tool.icon size={20} style={{ color: 'var(--accent)', marginTop: 2, flexShrink: 0 }} />
            <div>
              <div className="text-sm font-medium">{tool.title}</div>
              <div className="text-xs mt-0.5" style={{ color: 'var(--text-secondary)' }}>{tool.description}</div>
            </div>
          </button>
        ))}
      </div>
    </div>
  );
}
