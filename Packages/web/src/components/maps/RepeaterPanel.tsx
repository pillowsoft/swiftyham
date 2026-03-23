import { useState } from 'react';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Radio } from 'lucide-react';

const REPEATERS = [
  { call: 'W1AW', freq: '146.940', offset: '-0.600', tone: '100.0', mode: 'FM', city: 'Newington', state: 'CT' },
  { call: 'WB2ZII', freq: '147.060', offset: '+0.600', tone: '136.5', mode: 'FM', city: 'New York', state: 'NY' },
  { call: 'N1MU', freq: '449.575', offset: '-5.000', tone: '110.9', mode: 'FM', city: 'Worcester', state: 'MA' },
  { call: 'K1RK', freq: '145.230', offset: '-0.600', tone: '88.5', mode: 'FM', city: 'Hartford', state: 'CT' },
  { call: 'WA1ZYX', freq: '442.200', offset: '+5.000', tone: '100.0', mode: 'DMR', city: 'Enfield', state: 'CT' },
  { call: 'W1HDN', freq: '147.390', offset: '+0.600', tone: '77.0', mode: 'FM', city: 'Meriden', state: 'CT' },
  { call: 'KB1AEV', freq: '443.050', offset: '+5.000', tone: '100.0', mode: 'D-Star', city: 'Farmington', state: 'CT' },
  { call: 'N1GY', freq: '146.700', offset: '-0.600', tone: '156.7', mode: 'FM', city: 'Middletown', state: 'CT' },
];

export function RepeaterPanel() {
  const [search, setSearch] = useState('');
  const [bandFilter, setBandFilter] = useState('all');
  const filtered = REPEATERS.filter(r => {
    if (search && !r.call.toLowerCase().includes(search.toLowerCase()) && !r.city.toLowerCase().includes(search.toLowerCase())) return false;
    if (bandFilter === '2m' && !r.freq.startsWith('14')) return false;
    if (bandFilter === '70cm' && !r.freq.startsWith('4')) return false;
    return true;
  });

  return (
    <ScrollArea className="flex-1">
      <div className="p-4 space-y-4">
        <h2 className="text-base font-semibold">Repeaters</h2>
        <div className="flex gap-2">
          <Input className="flex-1" placeholder="Search by callsign or city..." value={search} onChange={(e) => setSearch(e.target.value)} />
          <Select value={bandFilter} onValueChange={setBandFilter}>
            <SelectTrigger className="w-32"><SelectValue placeholder="Band" /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Bands</SelectItem>
              <SelectItem value="2m">2m</SelectItem>
              <SelectItem value="70cm">70cm</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="space-y-1">
          {filtered.map(r => (
            <Card key={`${r.call}-${r.freq}`} className="flex items-center gap-3 px-3 py-2">
              <Radio size={16} className="text-primary shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-mono font-medium text-primary">{r.call}</span>
                  <Badge variant={r.mode === 'FM' ? 'gray' : r.mode === 'DMR' ? 'green' : 'default'}>{r.mode}</Badge>
                </div>
                <div className="text-[11px] text-muted-foreground">{r.city}, {r.state}</div>
              </div>
              <div className="text-right shrink-0">
                <div className="text-sm font-mono font-medium">{r.freq}</div>
                <div className="text-[10px] font-mono text-muted-foreground">{r.offset} &bull; {r.tone} Hz</div>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </ScrollArea>
  );
}
