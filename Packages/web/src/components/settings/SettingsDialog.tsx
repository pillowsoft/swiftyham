import { useState } from 'react';
import { useSnapshot } from 'valtio';
import { appStore, saveProfile, type Theme, setTheme } from '@/stores/app';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from '@/components/ui/select';
import { Separator } from '@/components/ui/separator';
import { ScrollArea } from '@/components/ui/scroll-area';

interface Props { onClose: () => void; }
type Tab = 'general' | 'ai' | 'about';

export function SettingsDialog({ onClose }: Props) {
  const snap = useSnapshot(appStore);
  const [tab, setTab] = useState<Tab>('general');

  return (
    <Dialog open onOpenChange={(open) => { if (!open) onClose(); }}>
      <DialogContent className="max-w-lg h-[420px] flex flex-col p-0">
        <DialogHeader className="px-5 pt-5 pb-3">
          <DialogTitle>Settings</DialogTitle>
        </DialogHeader>
        <div className="flex flex-1 overflow-hidden">
          <div className="w-32 py-2 shrink-0 border-r border-[var(--border)] bg-[var(--bg)]">
            {(['general', 'ai', 'about'] as Tab[]).map(t => (
              <Button key={t} variant={tab === t ? 'default' : 'ghost'} size="sm"
                className="w-full justify-start rounded-none capitalize" onClick={() => setTab(t)}>
                {t}
              </Button>
            ))}
          </div>
          <ScrollArea className="flex-1 p-4">
            {tab === 'general' && <GeneralSettings />}
            {tab === 'ai' && <AISettings />}
            {tab === 'about' && <AboutSettings />}
          </ScrollArea>
        </div>
      </DialogContent>
    </Dialog>
  );
}

function GeneralSettings() {
  const snap = useSnapshot(appStore);
  return (
    <div className="space-y-4">
      <div><Label className="block mb-1.5">Callsign</Label>
        <Input className="font-mono uppercase" value={snap.operatorCallsign} placeholder="W1AW"
          onChange={(e) => { appStore.operatorCallsign = e.target.value.toUpperCase(); }} onBlur={saveProfile} /></div>
      <div><Label className="block mb-1.5">Grid Square</Label>
        <Input className="font-mono" value={snap.gridSquare} placeholder="FN31pr"
          onChange={(e) => { appStore.gridSquare = e.target.value; }} onBlur={saveProfile} /></div>
      <div><Label className="block mb-1.5">Name</Label>
        <Input value={snap.operatorName} onChange={(e) => { appStore.operatorName = e.target.value; }} onBlur={saveProfile} /></div>
      <div><Label className="block mb-1.5">Theme</Label>
        <div className="flex gap-2">
          {(['dark', 'light', 'night'] as Theme[]).map(t => (
            <Button key={t} variant={snap.theme === t ? 'default' : 'secondary'} size="sm" className="capitalize" onClick={() => setTheme(t)}>{t}</Button>
          ))}
        </div>
      </div>
    </div>
  );
}

function AISettings() {
  return (
    <div className="space-y-4">
      <p className="text-xs text-[var(--text-secondary)]">AI features use on-device models or cloud APIs.</p>
      <div><Label className="block mb-1.5">AI Provider</Label>
        <Select defaultValue="local">
          <SelectTrigger><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="local">Local (MLX — requires bridge)</SelectItem>
            <SelectItem value="openrouter">OpenRouter (Claude)</SelectItem>
            <SelectItem value="anthropic">Anthropic (Direct)</SelectItem>
          </SelectContent>
        </Select>
      </div>
      <p className="text-[10px] text-[var(--text-muted)]">Local AI requires the HamStation Bridge CLI.</p>
    </div>
  );
}

function AboutSettings() {
  return (
    <div className="space-y-3 text-center py-4">
      <div className="text-lg font-bold text-[var(--accent)]">HamStation Pro</div>
      <div className="text-xs text-[var(--text-muted)]">Web Edition &bull; v0.1.0</div>
      <Separator />
      <p className="text-xs text-[var(--text-secondary)]">The modern amateur radio station for the web.</p>
      <p className="text-[10px] text-[var(--text-muted)]">MIT License &bull; Built with React, Valtio, and ShadCN/ui</p>
    </div>
  );
}
