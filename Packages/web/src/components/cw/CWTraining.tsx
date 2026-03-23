import { useState, useRef, useCallback } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { Play, Square, RotateCcw } from 'lucide-react';

const MORSE: Record<string, string> = {
  'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.',
  'G': '--.', 'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..',
  'M': '--', 'N': '-.', 'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.',
  'S': '...', 'T': '-', 'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-',
  'Y': '-.--', 'Z': '--..', '0': '-----', '1': '.----', '2': '..---',
  '3': '...--', '4': '....-', '5': '.....', '6': '-....', '7': '--...',
  '8': '---..', '9': '----.', '/': '-..-.', '?': '..--..', '.': '.-.-.-',
};

const KOCH_ORDER = 'KMRSUAPTLOWI.NJEF0Y,VG5/Q9ZH38B?427C1D6X'.split('');

export function CWTraining() {
  return (
    <div className="flex-1 overflow-auto p-4">
      <h2 className="text-base font-semibold mb-4">CW Training</h2>

      <Tabs defaultValue="koch">
        <TabsList>
          <TabsTrigger value="koch">Koch Trainer</TabsTrigger>
          <TabsTrigger value="callsign">Callsign Practice</TabsTrigger>
          <TabsTrigger value="reference">Morse Reference</TabsTrigger>
        </TabsList>

        <TabsContent value="koch">
          <KochTrainer />
        </TabsContent>
        <TabsContent value="callsign">
          <CallsignPractice />
        </TabsContent>
        <TabsContent value="reference">
          <MorseReference />
        </TabsContent>
      </Tabs>
    </div>
  );
}

function KochTrainer() {
  const [level, setLevel] = useState(2);
  const [wpm, setWpm] = useState(20);
  const [playing, setPlaying] = useState(false);
  const [currentChar, setCurrentChar] = useState('');
  const [userInput, setUserInput] = useState('');
  const [score, setScore] = useState({ correct: 0, total: 0 });
  const audioCtx = useRef<AudioContext | null>(null);

  const chars = KOCH_ORDER.slice(0, level);

  const playTone = useCallback((freq: number, durationMs: number) => {
    if (!audioCtx.current) audioCtx.current = new AudioContext();
    const ctx = audioCtx.current;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.frequency.value = freq;
    gain.gain.value = 0.3;
    osc.start(ctx.currentTime);
    osc.stop(ctx.currentTime + durationMs / 1000);
  }, []);

  const playChar = useCallback(async (char: string) => {
    const morse = MORSE[char];
    if (!morse) return;
    const ditMs = 1200 / wpm;

    for (const symbol of morse) {
      const dur = symbol === '.' ? ditMs : ditMs * 3;
      playTone(700, dur);
      await new Promise(r => setTimeout(r, dur + ditMs));
    }
  }, [wpm, playTone]);

  const playRound = useCallback(async () => {
    setPlaying(true);
    const char = chars[Math.floor(Math.random() * chars.length)];
    setCurrentChar(char);
    setUserInput('');
    await playChar(char);
    setPlaying(false);
  }, [chars, playChar]);

  function checkAnswer() {
    const correct = userInput.toUpperCase() === currentChar;
    setScore(prev => ({ correct: prev.correct + (correct ? 1 : 0), total: prev.total + 1 }));
    if (correct && score.total > 0 && (score.correct + 1) / (score.total + 1) > 0.9 && level < KOCH_ORDER.length) {
      setLevel(prev => prev + 1);
    }
    playRound();
  }

  const accuracy = score.total > 0 ? Math.round((score.correct / score.total) * 100) : 0;

  return (
    <div className="max-w-md">
      <div className="flex items-center gap-3 mb-4">
        <div>
          <label className="text-[10px] uppercase tracking-wider block mb-1" style={{ color: 'var(--text-muted)' }}>Level</label>
          <div className="flex items-center gap-2">
            <Button variant="secondary" size="sm" onClick={() => setLevel(Math.max(2, level - 1))}>-</Button>
            <span className="font-mono text-lg font-bold w-8 text-center">{level}</span>
            <Button variant="secondary" size="sm" onClick={() => setLevel(Math.min(KOCH_ORDER.length, level + 1))}>+</Button>
          </div>
        </div>
        <div>
          <label className="text-[10px] uppercase tracking-wider block mb-1" style={{ color: 'var(--text-muted)' }}>WPM</label>
          <div className="flex items-center gap-2">
            <Button variant="secondary" size="sm" onClick={() => setWpm(Math.max(5, wpm - 5))}>-</Button>
            <span className="font-mono text-lg font-bold w-8 text-center">{wpm}</span>
            <Button variant="secondary" size="sm" onClick={() => setWpm(Math.min(50, wpm + 5))}>+</Button>
          </div>
        </div>
      </div>

      <div className="mb-3">
        <label className="text-[10px] uppercase tracking-wider block mb-1" style={{ color: 'var(--text-muted)' }}>Characters</label>
        <div className="flex flex-wrap gap-1">
          {chars.map(c => <Badge key={c}>{c}</Badge>)}
        </div>
      </div>

      <Separator className="my-4" />

      <div className="flex gap-2 mb-4">
        <Button onClick={playRound} disabled={playing}>
          <Play size={14} /> {playing ? 'Playing...' : 'Play'}
        </Button>
        <Button variant="secondary" onClick={() => setScore({ correct: 0, total: 0 })}>
          <RotateCcw size={14} /> Reset
        </Button>
      </div>

      {currentChar && (
        <div className="flex gap-2 mb-4">
          <Input
            className="font-mono uppercase w-16 text-center text-lg"
            maxLength={1}
            value={userInput}
            onChange={(e) => setUserInput(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') checkAnswer(); }}
            placeholder="?"
            autoFocus
          />
          <Button onClick={checkAnswer} disabled={!userInput}>Check</Button>
        </div>
      )}

      <div className="flex gap-4 text-xs" style={{ color: 'var(--text-muted)' }}>
        <span>Score: {score.correct}/{score.total}</span>
        <span>Accuracy: {accuracy}%</span>
      </div>
    </div>
  );
}

function CallsignPractice() {
  const [playing, setPlaying] = useState(false);
  const audioCtx = useRef<AudioContext | null>(null);

  const SAMPLE_CALLS = ['W1AW', 'JA1ABC', 'DL1ABC', 'VK2RZA', 'G4ABC', 'PY2ABC', 'UA3ABC', 'ZL3AB', 'VE3ABC', '9A2ABC'];
  const [current, setCurrent] = useState('');
  const [userInput, setUserInput] = useState('');
  const [result, setResult] = useState<'correct' | 'wrong' | null>(null);

  function newCallsign() {
    const call = SAMPLE_CALLS[Math.floor(Math.random() * SAMPLE_CALLS.length)];
    setCurrent(call);
    setUserInput('');
    setResult(null);
  }

  function check() {
    setResult(userInput.toUpperCase() === current ? 'correct' : 'wrong');
  }

  return (
    <div className="max-w-md">
      <p className="text-xs mb-4" style={{ color: 'var(--text-secondary)' }}>
        Practice copying callsigns. A random callsign will be played — type what you hear.
      </p>

      <Button onClick={newCallsign} className="mb-4">
        <Play size={14} /> New Callsign
      </Button>

      {current && (
        <div className="space-y-3">
          <div className="flex gap-2">
            <Input
              className="font-mono uppercase flex-1"
              value={userInput}
              onChange={(e) => setUserInput(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') check(); }}
              placeholder="Type callsign..."
              autoFocus
            />
            <Button onClick={check}>Check</Button>
          </div>

          {result && (
            <div className="flex items-center gap-2">
              <Badge variant={result === 'correct' ? 'green' : 'red'}>
                {result === 'correct' ? 'Correct!' : 'Wrong'}
              </Badge>
              {result === 'wrong' && (
                <span className="font-mono text-sm" style={{ color: 'var(--accent)' }}>
                  Answer: {current}
                </span>
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function MorseReference() {
  return (
    <div className="grid grid-cols-4 gap-1">
      {Object.entries(MORSE).map(([char, code]) => (
        <div key={char} className="flex items-center gap-2 px-2 py-1 rounded text-xs"
          style={{ background: 'var(--bg-surface)', border: '1px solid var(--border-subtle)' }}>
          <span className="font-mono font-bold w-4 text-center" style={{ color: 'var(--accent)' }}>{char}</span>
          <span className="font-mono" style={{ color: 'var(--text-secondary)', letterSpacing: '0.1em' }}>{code}</span>
        </div>
      ))}
    </div>
  );
}
