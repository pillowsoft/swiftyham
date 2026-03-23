import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { ScrollArea } from '@/components/ui/scroll-area';
import { FileText, Radio, Mail, Plus } from 'lucide-react';

const FORMS = [
  { id: '1', type: 'ICS-213', subject: 'Supply Request — Water', to: 'EOC', from: 'Shelter A', status: 'sent', time: '14:30' },
  { id: '2', type: 'ICS-214', subject: 'Unit Activity Log', to: 'Planning', from: 'Net Control', status: 'draft', time: '13:45' },
  { id: '3', type: 'ICS-309', subject: 'Communications Log', to: 'ARES', from: 'W1AW', status: 'complete', time: '12:00' },
];

export function EmCommPanel() {
  return (
    <ScrollArea className="flex-1">
      <div className="p-4 space-y-4">
        <h2 className="text-base font-semibold">Emergency Communications</h2>
        <Tabs defaultValue="forms">
          <TabsList>
            <TabsTrigger value="forms"><FileText size={12} className="mr-1" /> ICS Forms</TabsTrigger>
            <TabsTrigger value="netlog"><Radio size={12} className="mr-1" /> Net Logger</TabsTrigger>
            <TabsTrigger value="winlink"><Mail size={12} className="mr-1" /> Winlink</TabsTrigger>
          </TabsList>
          <TabsContent value="forms">
            <div className="flex items-center justify-between mb-3">
              <p className="text-xs text-muted-foreground">Create and manage ICS forms for emergency operations.</p>
              <Button size="sm"><Plus size={12} /> New Form</Button>
            </div>
            <div className="space-y-1">
              {FORMS.map(form => (
                <Card key={form.id} className="flex items-center gap-3 px-3 py-2 cursor-pointer">
                  <FileText size={16} className="text-primary shrink-0" />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <Badge>{form.type}</Badge>
                      <span className="text-sm truncate">{form.subject}</span>
                    </div>
                    <div className="text-[11px] text-muted-foreground">From: {form.from} → To: {form.to}</div>
                  </div>
                  <div className="text-right shrink-0">
                    <Badge variant={form.status === 'sent' ? 'green' : form.status === 'complete' ? 'gray' : 'yellow'}>{form.status}</Badge>
                    <div className="text-[10px] font-mono mt-0.5 text-muted-foreground">{form.time}</div>
                  </div>
                </Card>
              ))}
            </div>
          </TabsContent>
          <TabsContent value="netlog">
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Radio size={32} className="mb-3 opacity-30" />
              <p className="text-sm font-medium text-muted-foreground">Net Logger</p>
              <p className="text-xs mt-1">Track check-ins and traffic during net operations</p>
            </div>
          </TabsContent>
          <TabsContent value="winlink">
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <Mail size={32} className="mb-3 opacity-30" />
              <p className="text-sm font-medium text-muted-foreground">Winlink</p>
              <p className="text-xs mt-1">Email over radio — requires bridge connection</p>
            </div>
          </TabsContent>
        </Tabs>
      </div>
    </ScrollArea>
  );
}
