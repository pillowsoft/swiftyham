import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/cn';

const badgeVariants = cva(
  'inline-flex items-center rounded px-1.5 py-0.5 text-[10px] font-medium font-mono transition-colors',
  {
    variants: {
      variant: {
        default: 'bg-[var(--accent-dim)] text-[var(--accent)]',
        green: 'bg-[color-mix(in_srgb,var(--green)_15%,transparent)] text-[var(--green)]',
        yellow: 'bg-[color-mix(in_srgb,var(--yellow)_15%,transparent)] text-[var(--yellow)]',
        red: 'bg-[color-mix(in_srgb,var(--red)_15%,transparent)] text-[var(--red)]',
        gray: 'bg-[color-mix(in_srgb,var(--gray)_15%,transparent)] text-[var(--gray)]',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  }
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />;
}

export { Badge, badgeVariants };
