'use client';

import { useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import PageHeader from '@/components/PageHeader';
import StatCard from '@/components/StatCard';
import { api, getToken } from '@/lib/api';
import { DashboardData, VpnServer } from '@/lib/types';

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [servers, setServers] = useState<VpnServer[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = getToken();
    if (!token) {
      setError('Не авторизован. Вернитесь на страницу входа.');
      return;
    }

    api<DashboardData>('/admin/dashboard')
      .then(setData)
      .catch((e) => {
        console.error('Dashboard error:', e);
        setError(
          `Не удалось загрузить панель управления: ${e.message}. ` +
            `Если это повторяется — выйдите и войдите заново (выход внизу меню).`,
        );
      });
    api<VpnServer[]>('/servers/all')
      .then(setServers)
      .catch((e) => {
        console.error('Servers error:', e);
        setServers([]);
      });
  }, []);

  if (error) {
    return (
      <div className="glass-card text-rose-300">
        Не удалось загрузить панель управления: {error}
      </div>
    );
  }
  if (!data) return <div className="text-muted">Загрузка…</div>;

  // Дефолты на случай неполного ответа: лучше прочерк, чем падение страницы.
  const online = data.connections?.online ?? 0;
  const trafficMb = data.trafficMb ?? null;
  const trafficTracked = data.trafficTracked ?? false;
  const serversActive = data.servers?.active ?? 0;
  const serversDisabled = data.servers?.disabled ?? 0;

  return (
    <div>
      <PageHeader title="Панель управления" subtitle="Обзор сервиса" />
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Пользователей" value={data.users.total} hint={`+${data.users.newToday} сегодня`} accent="blue" />
        <StatCard
          label="Устройств онлайн"
          value={online}
          hint="открывали приложение за 15 мин"
          accent="green"
        />
        <StatCard
          label="Трафик"
          value={
            trafficTracked && trafficMb !== null
              ? `${(trafficMb / 1024).toFixed(1)} ГБ`
              : '—'
          }
          hint={trafficTracked ? 'за всё время' : 'учёт не ведётся'}
          accent="yellow"
        />
        <StatCard label="Premium пользователей" value={data.users.activePremium} accent="purple" />
      </div>

      <h2 className="font-semibold text-sm text-faint uppercase tracking-wider mb-3">
        Статус серверов ({serversActive} активных · {serversDisabled} отключено)
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
