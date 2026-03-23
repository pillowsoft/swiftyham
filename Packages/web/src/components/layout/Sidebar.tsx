import { useSnapshot } from 'valtio';
import { appStore, SIDEBAR_ITEMS, type SidebarSection } from '@/stores/app';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Separator } from '@/components/ui/separator';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/cn';
import {
  BookOpen, Globe, Activity, Earth, Medal, Mountain, Sun, Timer,
  Radio, AudioWaveform, Satellite, Waves, Brain, BarChart3, Map, Wrench
} from 'lucide-react';

const ICON_MAP: Record<string, React.ElementType> = {
  'book-open': BookOpen, globe: Globe, activity: Activity, earth: Earth,
  medal: Medal, mountain: Mountain, sun: Sun, timer: Timer, radio: Radio,
  'audio-waveform': AudioWaveform, satellite: Satellite, waves: Waves,
  brain: Brain, 'bar-chart-3': BarChart3, map: Map, wrench: Wrench,
};

export function Sidebar() {
  const snap = useSnapshot(appStore);

  return (
    <aside className="flex flex-col border-r border-border bg-card w-[220px] min-w-[200px] h-full">
      {/* App header */}
      <div className="flex items-center gap-2 px-5 py-3 border-b border-border">
        <Radio size={18} className="text-primary" />
        <span className="text-sm font-semibold tracking-wide text-primary">
          HAMSTATION PRO
        </span>
      </div>

      {/* Nav items */}
      <ScrollArea className="flex-1">
        <nav className="p-3">
          {SIDEBAR_ITEMS.map((item) => {
            const Icon = ICON_MAP[item.icon] || Radio;
            const active = snap.selectedSection === item.id;
            return (
              <Button
                key={item.id}
                variant="ghost"
                onClick={() => { appStore.selectedSection = item.id; }}
                className={cn(
                  'w-full justify-start gap-3 mb-0.5 font-normal',
                  active && 'bg-primary/10 text-primary hover:bg-primary/10 hover:text-primary',
                  !active && 'text-muted-foreground',
                )}
              >
                <Icon size={16} />
                <span className="flex-1 text-left">{item.label}</span>
                {item.bridgeRequired && !snap.bridgeAvailable && (
                  <span className="text-[9px] opacity-40">bridge</span>
                )}
              </Button>
            );
          })}
        </nav>
      </ScrollArea>
    </aside>
  );
}
