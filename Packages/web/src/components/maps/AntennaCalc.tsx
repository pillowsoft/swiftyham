import { useState } from 'react';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Input } from '@/components/ui/input';
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select';

export function AntennaCalc() {
  return (
    <div className="flex-1 overflow-auto p-4">
      <h2 className="text-base font-semibold mb-4">Antenna Tools</h2>

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
  );
}

function DipoleCalc() {
  const [freqMHz, setFreqMHz] = useState('14.074');
  const freq = parseFloat(freqMHz) || 14.074;
  const totalFt = 468 / freq;
  const legFt = totalFt / 2;
  const totalM = totalFt * 0.3048;
  const legM = legFt * 0.3048;
  const quarterWaveFt = 234 / freq;

  return (
    <div className="max-w-md space-y-4">
      <div>
        <Label>Frequency (MHz)</Label>
        <Input className="font-mono w-40" value={freqMHz} onChange={(e) => setFreqMHz(e.target.value)} />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <ResultCard label="Total Length" value={`${totalFt.toFixed(2)} ft`} sub={`${totalM.toFixed(2)} m`} />
        <ResultCard label="Each Leg" value={`${legFt.toFixed(2)} ft`} sub={`${legM.toFixed(2)} m`} />
        <ResultCard label="Quarter Wave" value={`${quarterWaveFt.toFixed(2)} ft`} sub={`${(quarterWaveFt * 0.3048).toFixed(2)} m`} />
        <ResultCard label="Formula" value="468 / f(MHz)" sub="Standard dipole" />
      </div>
    </div>
  );
}

function CoaxCalc() {
  const [freqMHz, setFreqMHz] = useState('14.074');
  const [lengthFt, setLengthFt] = useState('100');
  const [cable, setCable] = useState('rg8x');

  const freq = parseFloat(freqMHz) || 14;
  const length = parseFloat(lengthFt) || 100;

  // Loss per 100ft at various frequencies (approximate dB/100ft)
  const cables: Record<string, { name: string; loss: number }> = {
    'rg58': { name: 'RG-58', loss: 1.4 + freq * 0.03 },
    'rg8x': { name: 'RG-8X', loss: 1.0 + freq * 0.025 },
    'rg213': { name: 'RG-213', loss: 0.6 + freq * 0.015 },
    'lmr400': { name: 'LMR-400', loss: 0.3 + freq * 0.01 },
  };

  const cableInfo = cables[cable] || cables['rg8x'];
  const totalLoss = (cableInfo.loss * length / 100);

  return (
    <div className="max-w-md space-y-4">
      <div className="grid grid-cols-3 gap-2">
        <div>
          <Label>Cable Type</Label>
          <Select value={cable} onValueChange={setCable}>
            <SelectTrigger className="font-mono"><SelectValue /></SelectTrigger>
            <SelectContent>
              {Object.entries(cables).map(([id, info]) => (
                <SelectItem key={id} value={id}>{info.name}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
        <div>
          <Label>Freq (MHz)</Label>
          <Input className="font-mono" value={freqMHz} onChange={(e) => setFreqMHz(e.target.value)} />
        </div>
        <div>
          <Label>Length (ft)</Label>
          <Input className="font-mono" value={lengthFt} onChange={(e) => setLengthFt(e.target.value)} />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <ResultCard label="Total Loss" value={`${totalLoss.toFixed(2)} dB`} sub={`${cableInfo.name} @ ${freq} MHz`} />
        <ResultCard label="Power Through" value={`${(100 * Math.pow(10, -totalLoss / 10)).toFixed(1)}%`} sub="of input power" />
      </div>
    </div>
  );
}

function SWRCalc() {
  const [forward, setForward] = useState('100');
  const [reflected, setReflected] = useState('5');

  const fwd = parseFloat(forward) || 100;
  const ref = parseFloat(reflected) || 0;
  const gamma = Math.sqrt(ref / fwd);
  const swr = (1 + gamma) / (1 - gamma);
  const returnLoss = -10 * Math.log10(ref / fwd || 0.001);
  const mismatchLoss = -10 * Math.log10(1 - (ref / fwd));

  return (
    <div className="max-w-md space-y-4">
      <div className="grid grid-cols-2 gap-2">
        <div>
          <Label>Forward Power (W)</Label>
          <Input className="font-mono" value={forward} onChange={(e) => setForward(e.target.value)} />
        </div>
        <div>
          <Label>Reflected Power (W)</Label>
          <Input className="font-mono" value={reflected} onChange={(e) => setReflected(e.target.value)} />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <ResultCard label="SWR" value={`${swr.toFixed(2)} : 1`} sub={swr < 1.5 ? 'Excellent' : swr < 2.0 ? 'Good' : swr < 3.0 ? 'Fair' : 'Poor'} />
        <ResultCard label="Return Loss" value={`${returnLoss.toFixed(1)} dB`} sub="" />
        <ResultCard label="Mismatch Loss" value={`${mismatchLoss.toFixed(2)} dB`} sub="" />
        <ResultCard label="Reflection Coeff" value={`${gamma.toFixed(3)}`} sub={`${(gamma * 100).toFixed(1)}%`} />
      </div>
    </div>
  );
}

function Label({ children }: { children: React.ReactNode }) {
  return <label className="text-[10px] uppercase tracking-wider block mb-1" style={{ color: 'var(--text-muted)' }}>{children}</label>;
}

function ResultCard({ label, value, sub }: { label: string; value: string; sub: string }) {
  return (
    <div className="rounded-md p-3" style={{ border: '1px solid var(--border)', background: 'var(--bg-surface)' }}>
      <div className="text-[10px] uppercase tracking-wider" style={{ color: 'var(--text-muted)' }}>{label}</div>
      <div className="text-base font-bold font-mono mt-0.5" style={{ color: 'var(--accent)' }}>{value}</div>
      {sub && <div className="text-[10px] mt-0.5" style={{ color: 'var(--text-secondary)' }}>{sub}</div>}
    </div>
  );
}
