import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Separator } from '@/components/ui/separator';
import { Send, Brain, Zap, Medal, BarChart3 } from 'lucide-react';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  time: string;
}

export function AIAssistantChat() {
  const [messages, setMessages] = useState<Message[]>([
    {
      id: '1',
      role: 'assistant',
      content: 'Hello! I\'m your ham radio AI assistant. I can help with band conditions, contest strategy, QSL routing, award tracking, and general ham radio questions. What would you like to know?',
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    },
  ]);
  const [input, setInput] = useState('');

  function sendMessage() {
    if (!input.trim()) return;
    const userMsg: Message = {
      id: crypto.randomUUID(),
      role: 'user',
      content: input,
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };
    setMessages([...messages, userMsg]);
    setInput('');

    // Simulate response (will connect to bridge/cloud API later)
    setTimeout(() => {
      const response: Message = {
        id: crypto.randomUUID(),
        role: 'assistant',
        content: 'This is a demo response. Connect the HamStation Bridge for local AI, or configure an OpenRouter API key in Settings for cloud AI.',
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      };
      setMessages(prev => [...prev, response]);
    }, 500);
  }

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      {/* Quick actions */}
      <div className="flex gap-2 p-3" style={{ borderBottom: '1px solid var(--border)' }}>
        <QuickAction icon={<Zap size={12} />} label="Band advice" onClick={() => { setInput('Which bands should I try right now?'); }} />
        <QuickAction icon={<Medal size={12} />} label="QSL advice" onClick={() => { setInput('Best way to confirm my recent contacts?'); }} />
        <QuickAction icon={<BarChart3 size={12} />} label="Log analysis" onClick={() => { setInput('Analyze my recent operating patterns'); }} />
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-3 flex flex-col gap-3">
        {messages.map(msg => (
          <div
            key={msg.id}
            className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
          >
            <div
              className="max-w-[80%] rounded-lg px-3 py-2 text-sm"
              style={{
                background: msg.role === 'user' ? 'var(--accent-dim)' : 'var(--bg-tertiary)',
                borderColor: msg.role === 'user' ? 'var(--accent)' : 'var(--border)',
              }}
            >
              <p>{msg.content}</p>
              <p className="text-[10px] mt-1" style={{ color: 'var(--text-muted)' }}>{msg.time}</p>
            </div>
          </div>
        ))}
      </div>

      <Separator />

      {/* Input */}
      <div className="flex gap-2 p-3">
        <Input
          className="flex-1"
          placeholder="Ask about ham radio..."
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') sendMessage(); }}
        />
        <Button size="icon" onClick={sendMessage} disabled={!input.trim()}>
          <Send size={14} />
        </Button>
      </div>
    </div>
  );
}

function QuickAction({ icon, label, onClick }: { icon: React.ReactNode; label: string; onClick: () => void }) {
  return (
    <Button variant="secondary" size="sm" onClick={onClick} className="text-xs">
      {icon} {label}
    </Button>
  );
}
