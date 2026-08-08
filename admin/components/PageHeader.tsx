interface PageHeaderProps {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
}

export default function PageHeader({ title, subtitle, action }: PageHeaderProps) {
  return (
    <div className="flex items-center justify-between mb-6">
      <div>
        <h1 className="text-2xl font-bold">{title}</h1>
        {subtitle ? <p className="text-sm text-muted mt-1">{subtitle}</p> : null}
      </div>
      {action}
    </div>
  );
}
