import * as React from 'react';
import { cn } from '@/lib/cn';

const Textarea = React.forwardRef<HTMLTextAreaElement, React.TextareaHTMLAttributes<HTMLTextAreaElement>>(
  ({ className, ...props }, ref) => (
    <textarea
      ref={ref}
      className={cn(
        'flex min-h-[60px] w-full rounded-md border border-[var(--border)] bg-[var(--bg)] px-3 py-2 text-sm',
        'text-[var(--text)] placeholder:text-[var(--text-muted)]',
        'focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-[var(--accent)]',
        'disabled:cursor-not-allowed disabled:opacity-50 resize-none',
        className
      )}
      {...props}
    />
  )
);
Textarea.displayName = 'Textarea';

export { Textarea };
