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

  if (error) return <div className="glass-card text-rose-300">Не удалось загрузить аналитику: {error}</div>;
  if (!overview) return <div className="text-muted">Загрузка…</div>;

  const maxConnections = Math.max(...daily.map((d) => d.connections), 1);
  const maxTraffic = Math.max(...daily.map((d) => d.trafficMb), 1);

  return (
    <div>
      <PageHeader title="Аналитика" subtitle="Последние 7 дней" />
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Пользователей" value={overview.totalUsers} accent="blue" />
        <StatCard label="Подключений" value={overview.onlineConnections} hint="сейчас онлайн" accent="green" />
        <StatCard label="Трафик" value={`${(overview.trafficMb / 1024).toFixed(1)} ГБ`} accent="yellow" />
        <StatCard label="Доход (оценка)" value={`₽${overview.revenueUsd.toFixed(2)}`} hint="активные подписки" accent="purple" />
      </div>

      <h2 className="font-semibold text-sm text-faint uppercase tracking-wider mb-3">Подключения по дням</h2>
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

      <h2 className="font-semibold text-sm text-faint uppercase tracking-wider mb-3">Популярные серверы</h2>
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Сервер</th>
              <th>Подключений</th>
              <th>Трафик</th>
              <th>Загрузка</th>
            </tr>
          </thead>
          <tbody>
            {popular.map((p) => (
              <tr key={p.server?.id ?? p.connections}>
                <td className="text-text font-medium">{p.server?.name ?? 'неизвестный'}</td>
                <td>{p.connections}</td>
                <td>{(p.trafficMb / 1024).toFixed(1)} ГБ</td>
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
        {popular.length === 0 ? <div className="text-muted text-sm py-4">Подключений пока нет.</div> : null}
      </div>
    </div>
  );
}
