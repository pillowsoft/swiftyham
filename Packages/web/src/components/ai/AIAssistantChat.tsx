import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Separator } from '@/components/ui/separator';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Send, Zap, Medal, BarChart3 } from 'lucide-react';

interface Message { id: string; role: 'user' | 'assistant'; content: string; time: string; }

export function AIAssistantChat() {
  const [messages, setMessages] = useState<Message[]>([
    { id: '1', role: 'assistant', content: 'Hello! I\'m your ham radio AI assistant. Ask me about band conditions, contest strategy, QSL routing, or anything ham radio related.', time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) },
  ]);
  const [input, setInput] = useState('');

  function sendMessage() {
    if (!input.trim()) return;
    setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'user', content: input, time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }]);
    setInput('');
    setTimeout(() => {
      setMessages(prev => [...prev, { id: crypto.randomUUID(), role: 'assistant', content: 'This is a demo response. Connect the HamStation Bridge for local AI, or configure an OpenRouter API key in Settings.', time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) }]);
    }, 500);
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <div className="flex gap-2 p-3 border-b border-border">
        <Button variant="secondary" size="sm" onClick={() => setInput('Which bands should I try right now?')}><Zap size={12} /> Band advice</Button>
        <Button variant="secondary" size="sm" onClick={() => setInput('Best way to confirm my recent contacts?')}><Medal size={12} /> QSL advice</Button>
        <Button variant="secondary" size="sm" onClick={() => setInput('Analyze my recent operating patterns')}><BarChart3 size={12} /> Log analysis</Button>
      </div>

      <ScrollArea className="flex-1 p-3">
        <div className="flex flex-col gap-3">
          {messages.map(msg => (
            <div key={msg.id} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
              <div className={`max-w-[80%] rounded-lg px-3 py-2 text-sm ${msg.role === 'user' ? 'bg-primary/10' : 'bg-muted'}`}>
                <p>{msg.content}</p>
                <p className="text-[10px] mt-1 text-muted-foreground">{msg.time}</p>
              </div>
            </div>
          ))}
        </div>
      </ScrollArea>

      <Separator />
      <div className="flex gap-2 p-3">
        <Input className="flex-1" placeholder="Ask about ham radio..." value={input}
          onChange={(e) => setInput(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') sendMessage(); }} />
        <Button size="icon" onClick={sendMessage} disabled={!input.trim()}><Send size={14} /></Button>
      </div>
    </div>
  );
}
