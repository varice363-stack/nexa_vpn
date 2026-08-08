interface StatCardProps {
  label: string;
  value: string | number;
  hint?: string;
  accent?: 'blue' | 'green' | 'yellow' | 'red' | 'purple';
}

const ACCENTS: Record<string, string> = {
  blue: 'from-accent/30 to-transparent border-accent/30',
  green: 'from-emerald-400/30 to-transparent border-emerald-400/30',
  yellow: 'from-amber-400/30 to-transparent border-amber-400/30',
  red: 'from-rose-400/30 to-transparent border-rose-400/30',
  purple: 'from-purple-400/30 to-transparent border-purple-400/30',
};

export default function StatCard({ label, value, hint, accent = 'blue' }: StatCardProps) {
  return (
    <div className={`glass p-5 border bg-gradient-to-br ${ACCENTS[accent]}`}>
      <div className="text-xs text-faint uppercase tracking-wider">{label}</div>
      <div className="text-2xl font-bold mt-2">{value}</div>
      {hint ? <div className="text-xs text-muted mt-1">{hint}</div> : null}
    </div>
  );
}
