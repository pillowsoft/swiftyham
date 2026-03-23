import { useState } from 'react';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Input } from '@/components/ui/input';
import { Card, CardContent } from '@/components/ui/card';
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { ScrollArea } from '@/components/ui/scroll-area';

export function AntennaCalc() {
  return (
    <ScrollArea className="flex-1">
      <div className="p-4 space-y-4">
        <h2 className="text-base font-semibold">Antenna Tools</h2>
        <Tabs defaultValue="dipole">
          <TabsList>
            <TabsTrigger value="dipole">Dipole</TabsTrigger>
            <TabsTrigger value="coax">Coax Loss</TabsTrigger>
            <TabsTrigger value="swr">SWR</TabsTrigger>
          </TabsList>
          <TabsContent value="dipole"><DipoleCalc /></TabsContent>
          <TabsContent value="coax"><CoaxCalc /></TabsContent>
          <TabsContent value="swr"><SWRCalc /></TabsContent>
        </Tabs>
      </div>
    </ScrollArea>
  );
}

function R({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <Card><CardContent className="p-3">
      <Label className="block">{label}</Label>
      <div className="text-base font-bold font-mono text-primary mt-1">{value}</div>
      {sub && <div className="text-[10px] mt-0.5 text-muted-foreground">{sub}</div>}
    </CardContent></Card>
  );
}

function DipoleCalc() {
  const [f, setF] = useState('14.074');
  const freq = parseFloat(f) || 14.074;
  const total = 468 / freq; const leg = total / 2; const qw = 234 / freq;
  return (
    <div className="max-w-md space-y-4">
      <div><Label className="block mb-1.5">Frequency (MHz)</Label><Input className="font-mono w-40" value={f} onChange={e => setF(e.target.value)} /></div>
      <div className="grid grid-cols-2 gap-3">
        <R label="Total Length" value={`${total.toFixed(2)} ft`} sub={`${(total*0.3048).toFixed(2)} m`} />
        <R label="Each Leg" value={`${leg.toFixed(2)} ft`} sub={`${(leg*0.3048).toFixed(2)} m`} />
        <R label="Quarter Wave" value={`${qw.toFixed(2)} ft`} sub={`${(qw*0.3048).toFixed(2)} m`} />
        <R label="Formula" value="468 / f(MHz)" sub="Standard dipole" />
      </div>
    </div>
  );
}

function CoaxCalc() {
  const [f, setF] = useState('14.074'); const [l, setL] = useState('100'); const [cable, setCable] = useState('rg8x');
  const freq = parseFloat(f)||14; const length = parseFloat(l)||100;
  const cables: Record<string, { name: string; loss: number }> = {
    rg58: { name: 'RG-58', loss: 1.4+freq*0.03 }, rg8x: { name: 'RG-8X', loss: 1.0+freq*0.025 },
    rg213: { name: 'RG-213', loss: 0.6+freq*0.015 }, lmr400: { name: 'LMR-400', loss: 0.3+freq*0.01 },
  };
  const info = cables[cable]||cables.rg8x; const loss = info.loss*length/100;
  return (
    <div className="max-w-md space-y-4">
      <div className="grid grid-cols-3 gap-2">
        <div><Label className="block mb-1.5">Cable</Label>
          <Select value={cable} onValueChange={setCable}><SelectTrigger className="font-mono"><SelectValue /></SelectTrigger>
            <SelectContent>{Object.entries(cables).map(([id,i]) => <SelectItem key={id} value={id}>{i.name}</SelectItem>)}</SelectContent></Select></div>
        <div><Label className="block mb-1.5">Freq (MHz)</Label><Input className="font-mono" value={f} onChange={e => setF(e.target.value)} /></div>
        <div><Label className="block mb-1.5">Length (ft)</Label><Input className="font-mono" value={l} onChange={e => setL(e.target.value)} /></div>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <R label="Total Loss" value={`${loss.toFixed(2)} dB`} sub={`${info.name} @ ${freq} MHz`} />
        <R label="Power Through" value={`${(100*Math.pow(10,-loss/10)).toFixed(1)}%`} sub="of input power" />
      </div>
    </div>
  );
}

function SWRCalc() {
  const [fwd, setFwd] = useState('100'); const [ref, setRef] = useState('5');
  const f = parseFloat(fwd)||100; const r = parseFloat(ref)||0;
  const gamma = Math.sqrt(r/f); const swr = (1+gamma)/(1-gamma);
  const rl = -10*Math.log10(r/f||0.001); const ml = -10*Math.log10(1-(r/f));
  return (
    <div className="max-w-md space-y-4">
      <div className="grid grid-cols-2 gap-2">
        <div><Label className="block mb-1.5">Forward (W)</Label><Input className="font-mono" value={fwd} onChange={e => setFwd(e.target.value)} /></div>
        <div><Label className="block mb-1.5">Reflected (W)</Label><Input className="font-mono" value={ref} onChange={e => setRef(e.target.value)} /></div>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <R label="SWR" value={`${swr.toFixed(2)} : 1`} sub={swr<1.5?'Excellent':swr<2?'Good':swr<3?'Fair':'Poor'} />
        <R label="Return Loss" value={`${rl.toFixed(1)} dB`} />
        <R label="Mismatch Loss" value={`${ml.toFixed(2)} dB`} />
        <R label="Reflection" value={`${gamma.toFixed(3)}`} sub={`${(gamma*100).toFixed(1)}%`} />
      </div>
    </div>
  );
}
