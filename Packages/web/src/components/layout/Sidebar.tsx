import { useSnapshot } from 'valtio';
import { appStore, SIDEBAR_ITEMS, type SidebarSection } from '@/stores/app';
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
    <aside
      className="flex flex-col border-r h-full overflow-y-auto"
      style={{
        width: 210,
        minWidth: 180,
        background: 'var(--bg-surface)',
        borderColor: 'var(--border)',
      }}
    >
      {/* App header */}
      <div className="py-2 flex items-center gap-2" style={{ paddingLeft: 14, paddingRight: 12, borderBottom: '1px solid var(--border)' }}>
        <Radio size={16} style={{ color: 'var(--accent)' }} />
        <span className="text-xs font-semibold tracking-wide" style={{ color: 'var(--accent)' }}>
          HAMSTATION PRO
        </span>
      </div>

      {/* Nav items */}
      <nav className="flex-1 py-1">
        {SIDEBAR_ITEMS.map((item) => {
          const Icon = ICON_MAP[item.icon] || Radio;
          const active = snap.selectedSection === item.id;
          return (
            <button
              key={item.id}
              onClick={() => { appStore.selectedSection = item.id; }}
              className={cn(
                'w-full flex items-center gap-2 px-3 py-[5px] rounded text-[13px] transition-colors cursor-pointer',
                'hover:bg-[var(--bg-tertiary)]',
              )}
              style={{
                background: active ? 'var(--accent-dim)' : undefined,
                color: active ? 'var(--accent)' : 'var(--text-secondary)',
                marginLeft: 10,
                marginRight: 6,
                width: 'calc(100% - 16px)',
              }}
            >
              <Icon size={15} />
              <span>{item.label}</span>
              {item.bridgeRequired && !snap.bridgeAvailable && (
                <span className="ml-auto text-[9px] opacity-40">bridge</span>
              )}
            </button>
          );
        })}
      </nav>
    </aside>
  );
}
