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
    <aside className="flex flex-col border-r border-[var(--border)] bg-[var(--bg-surface)] w-[210px] min-w-[180px] h-full">
      {/* App header */}
      <div className="flex items-center gap-2 px-4 py-2.5 border-b border-[var(--border)]">
        <Radio size={16} className="text-[var(--accent)]" />
        <span className="text-xs font-semibold tracking-wide text-[var(--accent)]">
          HAMSTATION PRO
        </span>
      </div>

      {/* Nav items */}
      <ScrollArea className="flex-1">
        <nav className="py-1.5 px-2">
          {SIDEBAR_ITEMS.map((item) => {
            const Icon = ICON_MAP[item.icon] || Radio;
            const active = snap.selectedSection === item.id;
            return (
              <Button
                key={item.id}
                variant="ghost"
                size="sm"
                onClick={() => { appStore.selectedSection = item.id; }}
                className={cn(
                  'w-full justify-start gap-2 mb-0.5 h-8 text-[13px] font-normal',
                  active && 'bg-[var(--accent-dim)] text-[var(--accent)] hover:bg-[var(--accent-dim)] hover:text-[var(--accent)]',
                  !active && 'text-[var(--text-secondary)]',
                )}
              >
                <Icon size={15} />
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
