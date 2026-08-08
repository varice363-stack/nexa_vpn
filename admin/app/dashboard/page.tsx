'use client';

import { useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import PageHeader from '@/components/PageHeader';
import StatCard from '@/components/StatCard';
import { api } from '@/lib/api';
import { DashboardData, VpnServer } from '@/lib/types';

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [servers, setServers] = useState<VpnServer[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<DashboardData>('/admin/dashboard')
      .then(setData)
      .catch((e) => setError(e.message));
    api<VpnServer[]>('/servers/all')
      .then(setServers)
      .catch(() => setServers([]));
  }, []);

  if (error) {
    return (
      <div className="glass-card text-rose-300">
        Cannot load dashboard: {error}. Make sure the backend is running
        (see backend/README).
      </div>
    );
  }
  if (!data) return <div className="text-muted">Loading…</div>;

  return (
    <div>
      <PageHeader title="Dashboard" subtitle="Service overview" />
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Total users" value={data.users.total} hint={`+${data.users.newToday} today`} accent="blue" />
        <StatCard label="Online connections" value={data.connections.online} accent="green" />
        <StatCard label="Traffic" value={`${(data.trafficMb / 1024).toFixed(1)} GB`} hint="all time" accent="yellow" />
        <StatCard label="Premium users" value={data.users.activePremium} accent="purple" />
      </div>

      <h2 className="font-semibold text-sm text-faint uppercase tracking-wider mb-3">
        Servers status ({data.servers.active} active · {data.servers.disabled} disabled)
      </h2>
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Name</th>
              <th>Location</th>
              <th>Ping</th>
              <th>Load</th>
              <th>Protocol</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {servers.map((s) => (
              <tr key={s.id}>
                <td className="text-text font-medium">{s.name}</td>
                <td>{s.city}, {s.country}</td>
                <td>{s.ping} ms</td>
                <td>{Math.round(s.load * 100)}%</td>
                <td>{s.protocol}</td>
                <td><Badge value={s.status} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
