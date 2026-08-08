'use client';

import { useEffect, useState } from 'react';

import PageHeader from '@/components/PageHeader';
import StatCard from '@/components/StatCard';
import { api } from '@/lib/api';
import { DailyStat, OverviewData, PopularServer } from '@/lib/types';

export default function AnalyticsPage() {
  const [overview, setOverview] = useState<OverviewData | null>(null);
  const [daily, setDaily] = useState<DailyStat[]>([]);
  const [popular, setPopular] = useState<PopularServer[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<OverviewData>('/analytics/overview').then(setOverview).catch((e) => setError(e.message));
    api<DailyStat[]>('/analytics/daily?days=7').then(setDaily).catch(() => undefined);
    api<PopularServer[]>('/analytics/popular-servers').then(setPopular).catch(() => undefined);
  }, []);

  if (error) return <div className="glass-card text-rose-300">Cannot load analytics: {error}</div>;
  if (!overview) return <div className="text-muted">Loading…</div>;

  const maxConnections = Math.max(...daily.map((d) => d.connections), 1);
  const maxTraffic = Math.max(...daily.map((d) => d.trafficMb), 1);

  return (
    <div>
      <PageHeader title="Analytics" subtitle="Last 7 days" />
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Daily users" value={overview.totalUsers} accent="blue" />
        <StatCard label="Connections" value={overview.onlineConnections} hint="currently online" accent="green" />
        <StatCard label="Traffic" value={`${(overview.trafficMb / 1024).toFixed(1)} GB`} accent="yellow" />
        <StatCard label="Revenue (est.)" value={`$${overview.revenueUsd.toFixed(2)}`} hint="active subscriptions" accent="purple" />
      </div>

      <h2 className="font-semibold text-sm text-faint uppercase tracking-wider mb-3">Daily connections</h2>
      <div className="glass p-5 mb-8">
        <div className="flex items-end gap-3 h-40">
          {daily.map((d) => (
            <div key={d.day} className="flex-1 flex flex-col items-center gap-1">
              <div className="text-[10px] text-faint">{d.trafficMb > 0 ? `${(d.trafficMb / 1024).toFixed(1)}GB` : ''}</div>
              <div
                className="w-full rounded-t-md bg-gradient-to-t from-accent/60 to-accentbright/30"
                style={{ height: `${Math.max((d.connections / maxConnections) * 100, 3)}%` }}
              />
              <div className="text-[10px] text-faint">{d.day.slice(5)}</div>
            </div>
          ))}
        </div>
      </div>

      <h2 className="font-semibold text-sm text-faint uppercase tracking-wider mb-3">Popular servers</h2>
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Server</th>
              <th>Connections</th>
              <th>Traffic</th>
              <th>Load</th>
            </tr>
          </thead>
          <tbody>
            {popular.map((p) => (
              <tr key={p.server?.id ?? p.connections}>
                <td className="text-text font-medium">{p.server?.name ?? 'unknown'}</td>
                <td>{p.connections}</td>
                <td>{(p.trafficMb / 1024).toFixed(1)} GB</td>
                <td>
                  <div className="w-24 h-2 rounded-full bg-white/10">
                    <div
                      className="h-full rounded-full bg-gradient-to-r from-accent to-emerald-400"
                      style={{ width: `${Math.min((p.server?.load ?? 0) * 100, 100)}%` }}
                    />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {popular.length === 0 ? <div className="text-muted text-sm py-4">No connections yet.</div> : null}
      </div>
    </div>
  );
}
