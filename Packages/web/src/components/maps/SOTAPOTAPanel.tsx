import { useState } from 'react';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Mountain, Trees } from 'lucide-react';

const SAMPLE_SUMMITS = [
  { ref: 'W4C/CM-001', name: 'Mt. Mitchell', alt: 2037, pts: 10, state: 'NC' },
  { ref: 'W1/HA-001', name: 'Mt. Washington', alt: 1917, pts: 10, state: 'NH' },
  { ref: 'W7A/MO-001', name: 'Humphreys Peak', alt: 3852, pts: 10, state: 'AZ' },
  { ref: 'W0C/FR-001', name: 'Mt. Elbert', alt: 4401, pts: 10, state: 'CO' },
  { ref: 'W6/CT-001', name: 'Mt. Whitney', alt: 4421, pts: 10, state: 'CA' },
];

const SAMPLE_PARKS = [
  { ref: 'K-0001', name: 'Yellowstone NP', state: 'WY', type: 'NP' },
  { ref: 'K-0003', name: 'Grand Canyon NP', state: 'AZ', type: 'NP' },
  { ref: 'K-0010', name: 'Yosemite NP', state: 'CA', type: 'NP' },
  { ref: 'K-0034', name: 'Great Smoky Mtns NP', state: 'TN', type: 'NP' },
  { ref: 'K-0042', name: 'Acadia NP', state: 'ME', type: 'NP' },
];

export function SOTAPOTAPanel() {
  const [search, setSearch] = useState('');

  return (
    <div className="flex-1 overflow-auto p-4">
      <h2 className="text-base font-semibold mb-4">SOTA / POTA</h2>

      <Input className="mb-4" placeholder="Search summits or parks..." value={search} onChange={(e) => setSearch(e.target.value)} />

      <Tabs defaultValue="sota">
        <TabsList>
          <TabsTrigger value="sota"><Mountain size={12} className="mr-1" /> SOTA</TabsTrigger>
          <TabsTrigger value="pota"><Trees size={12} className="mr-1" /> POTA</TabsTrigger>
        </TabsList>

        <TabsContent value="sota">
          <div className="space-y-1">
            {SAMPLE_SUMMITS.filter(s => !search || s.name.toLowerCase().includes(search.toLowerCase()) || s.ref.toLowerCase().includes(search.toLowerCase())).map(s => (
              <div key={s.ref} className="flex items-center gap-3 px-3 py-2 rounded" style={{ border: '1px solid var(--border-subtle)' }}>
                <Mountain size={16} style={{ color: 'var(--accent)', flexShrink: 0 }} />
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-medium truncate">{s.name}</div>
                  <div className="text-[11px] font-mono" style={{ color: 'var(--text-muted)' }}>{s.ref} • {s.state}</div>
                </div>
                <div className="text-right flex-shrink-0">
                  <div className="text-xs font-mono">{s.alt}m</div>
                  <Badge variant="green">{s.pts} pts</Badge>
                </div>
              </div>
            ))}
          </div>
        </TabsContent>

        <TabsContent value="pota">
          <div className="space-y-1">
            {SAMPLE_PARKS.filter(p => !search || p.name.toLowerCase().includes(search.toLowerCase()) || p.ref.toLowerCase().includes(search.toLowerCase())).map(p => (
              <div key={p.ref} className="flex items-center gap-3 px-3 py-2 rounded" style={{ border: '1px solid var(--border-subtle)' }}>
                <Trees size={16} style={{ color: 'var(--green)', flexShrink: 0 }} />
                <div className="flex-1 min-w-0">
                  <div className="text-sm font-medium truncate">{p.name}</div>
                  <div className="text-[11px] font-mono" style={{ color: 'var(--text-muted)' }}>{p.ref} • {p.state}</div>
                </div>
                <Badge variant="gray">{p.type}</Badge>
              </div>
            ))}
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}
