import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { FileText, Radio, Mail, Plus } from 'lucide-react';

const SAMPLE_FORMS = [
  { id: '1', type: 'ICS-213', subject: 'Supply Request — Water', to: 'EOC', from: 'Shelter A', status: 'sent', time: '14:30' },
  { id: '2', type: 'ICS-214', subject: 'Unit Activity Log', to: 'Planning', from: 'Net Control', status: 'draft', time: '13:45' },
  { id: '3', type: 'ICS-309', subject: 'Communications Log', to: 'ARES', from: 'W1AW', status: 'complete', time: '12:00' },
];

export function EmCommPanel() {
  return (
    <div className="flex-1 overflow-auto p-4">
      <h2 className="text-base font-semibold mb-4">Emergency Communications</h2>

      <Tabs defaultValue="forms">
        <TabsList>
          <TabsTrigger value="forms"><FileText size={12} className="mr-1" /> ICS Forms</TabsTrigger>
          <TabsTrigger value="netlog"><Radio size={12} className="mr-1" /> Net Logger</TabsTrigger>
          <TabsTrigger value="winlink"><Mail size={12} className="mr-1" /> Winlink</TabsTrigger>
        </TabsList>

        <TabsContent value="forms">
          <div className="flex items-center justify-between mb-3">
            <p className="text-xs" style={{ color: 'var(--text-secondary)' }}>
              Create and manage ICS forms for emergency operations.
            </p>
            <Button size="sm"><Plus size={12} /> New Form</Button>
          </div>

          <div className="space-y-1">
            {SAMPLE_FORMS.map(form => (
              <div key={form.id} className="flex items-center gap-3 px-3 py-2 rounded cursor-pointer" style={{ border: '1px solid var(--border-subtle)' }}>
                <FileText size={16} style={{ color: 'var(--accent)', flexShrink: 0 }} />
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <Badge>{form.type}</Badge>
                    <span className="text-sm truncate">{form.subject}</span>
                  </div>
                  <div className="text-[11px]" style={{ color: 'var(--text-muted)' }}>
                    From: {form.from} → To: {form.to}
                  </div>
                </div>
                <div className="text-right flex-shrink-0">
                  <Badge variant={form.status === 'sent' ? 'green' : form.status === 'complete' ? 'gray' : 'yellow'}>
                    {form.status}
                  </Badge>
                  <div className="text-[10px] font-mono mt-0.5" style={{ color: 'var(--text-muted)' }}>{form.time}</div>
                </div>
              </div>
            ))}
          </div>
        </TabsContent>

        <TabsContent value="netlog">
          <div className="flex flex-col items-center justify-center py-12" style={{ color: 'var(--text-muted)' }}>
            <Radio size={32} className="mb-3 opacity-30" />
            <p className="text-sm font-medium" style={{ color: 'var(--text-secondary)' }}>Net Logger</p>
            <p className="text-xs mt-1">Track check-ins and traffic during net operations</p>
          </div>
        </TabsContent>

        <TabsContent value="winlink">
          <div className="flex flex-col items-center justify-center py-12" style={{ color: 'var(--text-muted)' }}>
            <Mail size={32} className="mb-3 opacity-30" />
            <p className="text-sm font-medium" style={{ color: 'var(--text-secondary)' }}>Winlink</p>
            <p className="text-xs mt-1">Email over radio — requires bridge connection</p>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}
