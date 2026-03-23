import { useState } from 'react';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Mountain, Trees } from 'lucide-react';

const SUMMITS = [
  { ref: 'W4C/CM-001', name: 'Mt. Mitchell', alt: 2037, pts: 10, state: 'NC' },
  { ref: 'W1/HA-001', name: 'Mt. Washington', alt: 1917, pts: 10, state: 'NH' },
  { ref: 'W7A/MO-001', name: 'Humphreys Peak', alt: 3852, pts: 10, state: 'AZ' },
  { ref: 'W0C/FR-001', name: 'Mt. Elbert', alt: 4401, pts: 10, state: 'CO' },
  { ref: 'W6/CT-001', name: 'Mt. Whitney', alt: 4421, pts: 10, state: 'CA' },
];
const PARKS = [
  { ref: 'K-0001', name: 'Yellowstone NP', state: 'WY', type: 'NP' },
  { ref: 'K-0003', name: 'Grand Canyon NP', state: 'AZ', type: 'NP' },
  { ref: 'K-0010', name: 'Yosemite NP', state: 'CA', type: 'NP' },
  { ref: 'K-0034', name: 'Great Smoky Mtns NP', state: 'TN', type: 'NP' },
  { ref: 'K-0042', name: 'Acadia NP', state: 'ME', type: 'NP' },
];

export function SOTAPOTAPanel() {
  const [search, setSearch] = useState('');
  return (
    <ScrollArea className="flex-1">
      <div className="p-4 space-y-4">
        <h2 className="text-base font-semibold">SOTA / POTA</h2>
        <Input placeholder="Search summits or parks..." value={search} onChange={(e) => setSearch(e.target.value)} />
        <Tabs defaultValue="sota">
          <TabsList>
            <TabsTrigger value="sota"><Mountain size={12} className="mr-1" /> SOTA</TabsTrigger>
            <TabsTrigger value="pota"><Trees size={12} className="mr-1" /> POTA</TabsTrigger>
          </TabsList>
          <TabsContent value="sota">
            <div className="space-y-1">
              {SUMMITS.filter(s => !search || s.name.toLowerCase().includes(search.toLowerCase()) || s.ref.toLowerCase().includes(search.toLowerCase())).map(s => (
                <Card key={s.ref} className="flex items-center gap-3 px-3 py-2">
                  <Mountain size={16} className="text-primary shrink-0" />
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium truncate">{s.name}</div>
                    <div className="text-[11px] font-mono text-muted-foreground">{s.ref} &bull; {s.state}</div>
                  </div>
                  <div className="text-right shrink-0">
                    <div className="text-xs font-mono">{s.alt}m</div>
                    <Badge variant="green">{s.pts} pts</Badge>
                  </div>
                </Card>
              ))}
            </div>
          </TabsContent>
          <TabsContent value="pota">
            <div className="space-y-1">
              {PARKS.filter(p => !search || p.name.toLowerCase().includes(search.toLowerCase()) || p.ref.toLowerCase().includes(search.toLowerCase())).map(p => (
                <Card key={p.ref} className="flex items-center gap-3 px-3 py-2">
                  <Trees size={16} className="text-success shrink-0" />
                  <div className="flex-1 min-w-0">
                    <div className="text-sm font-medium truncate">{p.name}</div>
                    <div className="text-[11px] font-mono text-muted-foreground">{p.ref} &bull; {p.state}</div>
                  </div>
                  <Badge variant="gray">{p.type}</Badge>
                </Card>
              ))}
            </div>
          </TabsContent>
        </Tabs>
      </div>
    </ScrollArea>
  );
}
