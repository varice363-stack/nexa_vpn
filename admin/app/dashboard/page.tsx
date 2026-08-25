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
        Не удалось загрузить панель управления: {error}. Убедитесь что backend запущен.
      </div>
    );
  }
  if (!data) return <div className="text-muted">Загрузка…</div>;

  return (
    <div>
      <PageHeader title="Панель управления" subtitle="Обзор сервиса" />
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Пользователей" value={data.users.total} hint={`+${data.users.newToday} сегодня`} accent="blue" />
        <StatCard label="Подключений онлайн" value={data.connections.online} accent="green" />
        <StatCard label="Трафик" value={`${(data.trafficMb / 1024).toFixed(1)} ГБ`} hint="за всё время" accent="yellow" />
        <StatCard label="Premium пользователей" value={data.users.activePremium} accent="purple" />
      </div>

      <h2 className="font-semibold text-sm text-faint uppercase tracking-wider mb-3">
        Статус серверов ({data.servers.active} активных · {data.servers.disabled} отключено)
      </h2>
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Название</th>
              <th>Локация</th>
              <th>Пинг</th>
              <th>Загрузка</th>
              <th>Протокол</th>
              <th>Статус</th>
            </tr>
          </thead>
          <tbody>
            {servers.map((s) => (
              <tr key={s.id}>
                <td className="text-text font-medium">{s.name}</td>
                <td>{s.city}, {s.country}</td>
                <td>{s.ping} мс</td>
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
