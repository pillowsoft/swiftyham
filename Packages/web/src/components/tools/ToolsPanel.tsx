import { appStore, type SidebarSection } from '@/stores/app';
import { Card, CardContent } from '@/components/ui/card';
import { ScrollArea } from '@/components/ui/scroll-area';
import { AudioWaveform, Satellite, BarChart3, Map } from 'lucide-react';

const TOOLS: { id: SidebarSection; icon: React.ElementType; title: string; description: string }[] = [
  { id: 'cwTraining', icon: AudioWaveform, title: 'CW Training', description: 'Koch trainer, callsign practice, QSO simulator' },
  { id: 'satellite', icon: Satellite, title: 'Satellite Tracker', description: 'Pass predictions, Doppler correction, polar plot' },
  { id: 'audioSpectrum', icon: BarChart3, title: 'Audio Spectrum', description: 'Real-time FFT analyzer and waterfall display' },
  { id: 'greatCircleMap', icon: Map, title: 'Great Circle Map', description: 'Azimuthal equidistant projection with beam headings' },
];

export function ToolsPanel() {
  return (
    <ScrollArea className="flex-1">
      <div className="p-4 space-y-4">
        <h2 className="text-base font-semibold">Tools</h2>
        <div className="grid grid-cols-2 gap-3">
          {TOOLS.map(tool => (
            <Card key={tool.id} className="cursor-pointer hover:bg-[var(--bg-tertiary)] transition-colors"
              onClick={() => { appStore.selectedSection = tool.id; }}>
              <CardContent className="p-3 flex items-start gap-3">
                <tool.icon size={20} className="text-[var(--accent)] mt-0.5 shrink-0" />
                <div>
                  <div className="text-sm font-medium">{tool.title}</div>
                  <div className="text-xs mt-0.5 text-[var(--text-secondary)]">{tool.description}</div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </ScrollArea>
  );
}
