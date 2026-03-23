import { useState } from 'react';
import { appStore, completeOnboarding, setTheme, type Theme } from '@/stores/app';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select';
import { Separator } from '@/components/ui/separator';
import { Radio, ArrowRight, ArrowLeft, Check } from 'lucide-react';

interface Props {
  open: boolean;
  onComplete: () => void;
}

type Step = 'welcome' | 'profile' | 'theme' | 'done';
const STEPS: Step[] = ['welcome', 'profile', 'theme', 'done'];

export function OnboardingWizard({ open, onComplete }: Props) {
  const [step, setStep] = useState<Step>('welcome');
  const [callsign, setCallsign] = useState('');
  const [name, setName] = useState('');
  const [grid, setGrid] = useState('');
  const [license, setLicense] = useState('Extra');
  const [theme, setThemeLocal] = useState<Theme>('dark');

  const stepIndex = STEPS.indexOf(step);

  function next() {
    const nextStep = STEPS[stepIndex + 1];
    if (nextStep) setStep(nextStep);
  }

  function back() {
    const prevStep = STEPS[stepIndex - 1];
    if (prevStep) setStep(prevStep);
  }

  function finish() {
    appStore.operatorCallsign = callsign.toUpperCase();
    appStore.operatorName = name;
    appStore.gridSquare = grid;
    appStore.licenseClass = license;
    setTheme(theme);
    completeOnboarding();
    onComplete();
  }

  return (
    <Dialog open={open} onOpenChange={() => {}}>
      <DialogContent className="max-w-md" onPointerDownOutside={(e) => e.preventDefault()}>
        {/* Progress dots */}
        <div className="flex justify-center gap-1.5 pt-2">
          {STEPS.map((s, i) => (
            <div
              key={s}
              className="rounded-full transition-colors"
              style={{
                width: 8, height: 8,
                background: i <= stepIndex ? 'var(--accent)' : 'var(--border)',
              }}
            />
          ))}
        </div>

        {step === 'welcome' && (
          <div className="text-center py-6 px-4">
            <Radio size={48} className="text-primary mx-auto mb-4" />
            <h2 className="text-xl font-bold mb-2">Welcome to HamStation Pro</h2>
            <p className="text-sm text-muted-foreground">
              The modern amateur radio station for the web.
              Log contacts, track DX, monitor propagation, and more.
            </p>
            <Button className="mt-6" onClick={next}>
              Get Started <ArrowRight size={14} />
            </Button>
          </div>
        )}

        {step === 'profile' && (
          <div className="px-5 py-4">
            <DialogHeader className="px-0">
              <DialogTitle>Operator Profile</DialogTitle>
              <DialogDescription>Tell us about your station.</DialogDescription>
            </DialogHeader>

            <div className="space-y-3 mt-4">
              <div>
                <Label>Callsign</Label>
                <Input
                  className="font-mono uppercase"
                  placeholder="W1AW"
                  value={callsign}
                  onChange={(e) => setCallsign(e.target.value)}
                  autoFocus
                />
              </div>
              <div>
                <Label>Name</Label>
                <Input placeholder="Your name" value={name} onChange={(e) => setName(e.target.value)} />
              </div>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <Label>Grid Square</Label>
                  <Input className="font-mono uppercase" placeholder="FN31pr" value={grid} onChange={(e) => setGrid(e.target.value)} />
                </div>
                <div>
                  <Label>License Class</Label>
                  <Select value={license} onValueChange={setLicense}>
                    <SelectTrigger><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="Technician">Technician</SelectItem>
                      <SelectItem value="General">General</SelectItem>
                      <SelectItem value="Extra">Extra</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </div>
          </div>
        )}

        {step === 'theme' && (
          <div className="px-5 py-4">
            <DialogHeader className="px-0">
              <DialogTitle>Choose Your Theme</DialogTitle>
              <DialogDescription>You can change this anytime in Settings.</DialogDescription>
            </DialogHeader>

            <div className="grid grid-cols-3 gap-3 mt-4">
              {([
                { id: 'dark' as Theme, label: 'Dark', desc: 'Default — easy on the eyes', bg: '#0F1117', text: '#F5F5F7', accent: '#FF6A00' },
                { id: 'light' as Theme, label: 'Light', desc: 'For daytime use', bg: '#FAFAFA', text: '#0A0A0F', accent: '#FF6A00' },
                { id: 'night' as Theme, label: 'Night', desc: 'Preserves dark vision', bg: '#0A0000', text: '#FF9999', accent: '#8B0000' },
              ]).map(t => (
                <button
                  key={t.id}
                  onClick={() => { setThemeLocal(t.id); setTheme(t.id); }}
                  className="rounded-lg p-3 text-center cursor-pointer transition-colors"
                  style={{
                    border: `2px solid ${theme === t.id ? 'var(--accent)' : 'var(--border)'}`,
                    background: theme === t.id ? 'var(--accent-dim)' : 'var(--bg-surface)',
                  }}
                >
                  <div className="rounded-md mb-2 mx-auto" style={{ width: 48, height: 32, background: t.bg, border: '1px solid var(--border)' }}>
                    <div className="mt-2 mx-auto rounded" style={{ width: 24, height: 4, background: t.accent }} />
                  </div>
                  <div className="text-xs font-medium">{t.label}</div>
                  <div className="text-[10px] text-muted-foreground">{t.desc}</div>
                </button>
              ))}
            </div>
          </div>
        )}

        {step === 'done' && (
          <div className="text-center py-6 px-4">
            <div className="rounded-full p-3 mx-auto w-fit mb-4" style={{ background: 'color-mix(in srgb, var(--green) 15%, transparent)' }}>
              <Check size={32} className="text-success" />
            </div>
            <h2 className="text-xl font-bold mb-2">You're All Set!</h2>
            <div className="space-y-1 text-sm mb-6 text-muted-foreground">
              {callsign && <p>Callsign: <span className="font-mono font-bold text-primary">{callsign.toUpperCase()}</span></p>}
              {grid && <p>Grid: <span className="font-mono">{grid}</span></p>}
              <p>License: {license}</p>
            </div>
            <Button onClick={finish}>
              Open HamStation Pro <ArrowRight size={14} />
            </Button>
          </div>
        )}

        {/* Navigation */}
        {step !== 'welcome' && step !== 'done' && (
          <DialogFooter>
            <Button variant="ghost" onClick={back}>
              <ArrowLeft size={14} /> Back
            </Button>
            <div className="flex-1" />
            <Button variant="ghost" size="sm" onClick={finish} className="text-xs text-muted-foreground">
              Skip
            </Button>
            <Button onClick={next}>
              Next <ArrowRight size={14} />
            </Button>
          </DialogFooter>
        )}
      </DialogContent>
    </Dialog>
  );
}

function Label({ children }: { children: React.ReactNode }) {
  return <label className="text-[10px] uppercase tracking-wider mb-1 block text-muted-foreground">{children}</label>;
}
