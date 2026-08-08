'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

import { clearToken } from '@/lib/api';

const NAV = [
  { href: '/dashboard', label: 'Dashboard', icon: '◈' },
  { href: '/users', label: 'Users', icon: '👥' },
  { href: '/servers', label: 'Servers', icon: '🖥' },
  { href: '/banners', label: 'Banners', icon: '🪧' },
  { href: '/analytics', label: 'Analytics', icon: '📈' },
];

const BILLING_NAV = [
  { href: '/plans', label: 'Plans', icon: '💎' },
  { href: '/subscriptions', label: 'Subscriptions', icon: '🔁' },
  { href: '/transactions', label: 'Transactions', icon: '💳' },
];

export default function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();

  return (
    <aside className="w-60 shrink-0 h-screen sticky top-0 flex flex-col border-r border-white/10 bg-surface/60 backdrop-blur">
      <div className="px-5 py-5 flex items-center gap-3 border-b border-white/10">
        <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-accent to-indigo-500 grid place-items-center text-white font-bold">
          N
        </div>
        <div>
          <div className="font-bold text-sm">Nexa VPN</div>
          <div className="text-[11px] text-faint">Admin Panel</div>
        </div>
      </div>

      <nav className="flex-1 px-3 py-4 space-y-1">
        {NAV.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition ${
                active
                  ? 'bg-gradient-to-r from-accent/25 to-indigo-500/15 text-text border border-accent/30'
                  : 'text-muted hover:text-text hover:bg-white/5'
              }`}
            >
              <span className="w-5 text-center">{item.icon}</span>
              {item.label}
            </Link>
          );
        })}
      </nav>

      <nav className="px-3 pb-4">
        <div className="text-[10px] uppercase tracking-wider text-faint px-3 pb-2">
          Billing
        </div>
        {BILLING_NAV.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition ${
                active
                  ? 'bg-gradient-to-r from-accent/25 to-indigo-500/15 text-text border border-accent/30'
                  : 'text-muted hover:text-text hover:bg-white/5'
              }`}
            >
              <span className="w-5 text-center">{item.icon}</span>
              {item.label}
            </Link>
          );
        })}
      </nav>

      <div className="p-3 border-t border-white/10">
        <button
          onClick={() => {
            clearToken();
            router.push('/login');
          }}
          className="w-full btn-ghost text-center"
        >
          Log out
        </button>
      </div>
    </aside>
  );
}
