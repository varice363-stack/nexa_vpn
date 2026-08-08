const STYLES: Record<string, string> = {
  ACTIVE: 'bg-emerald-400/15 text-emerald-300 border-emerald-400/30',
  BLOCKED: 'bg-rose-400/15 text-rose-300 border-rose-400/30',
  DISABLED: 'bg-rose-400/15 text-rose-300 border-rose-400/30',
  PREMIUM: 'bg-amber-400/15 text-amber-300 border-amber-400/30',
  USER: 'bg-white/10 text-muted border-white/10',
  ADMIN: 'bg-purple-400/15 text-purple-300 border-purple-400/30',
  EXPIRED: 'bg-white/10 text-faint border-white/10',
  CANCELLED: 'bg-white/10 text-faint border-white/10',
};

export default function Badge({ value }: { value: string }) {
  const cls = STYLES[value] ?? 'bg-white/10 text-muted border-white/10';
  return (
    <span className={`inline-block px-2.5 py-0.5 rounded-full text-[11px] font-semibold border ${cls}`}>
      {value}
    </span>
  );
}
