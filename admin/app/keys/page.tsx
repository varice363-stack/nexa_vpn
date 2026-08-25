'use client';

import { useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';
import { AdminAccessKey } from '@/lib/types';

export default function AccessKeysPage() {
  const [keys, setKeys] = useState<AdminAccessKey[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<AdminAccessKey[]>('/provisioning/all')
      .then(setKeys)
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <PageHeader title="Ключи доступа" subtitle="Все выпущенные ключи" />
      {error ? (
        <div className="glass-card text-rose-300 mb-3">{error}</div>
      ) : null}
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Пользователь</th>
              <th>Название</th>
              <th>Протокол</th>
              <th>Статус</th>
              <th>Назначенный сервер</th>
              <th>Статус сервера</th>
              <th>Устройство</th>
              <th>Создан</th>
              <th>Истекает</th>
            </tr>
          </thead>
          <tbody>
            {keys.map((k) => (
              <tr key={k.id}>
                <td className="text-text font-medium">{k.user?.email ?? k.userId}</td>
                <td>{k.name}</td>
                <td>{k.protocol}</td>
                <td><Badge value={k.status} /></td>
                <td>{k.server ? `${k.server.name} (${k.server.city})` : '—'}</td>
                <td>{k.server ? <Badge value={k.server.status} /> : '—'}</td>
                <td>{k.deviceId ? k.deviceId.slice(0, 8) : '—'}</td>
                <td>{new Date(k.createdAt).toLocaleDateString()}</td>
                <td>{k.expiresAt ? new Date(k.expiresAt).toLocaleDateString() : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {keys.length === 0 && !error ? (
          <div className="text-muted text-sm py-4">Ключей доступа пока нет.</div>
        ) : null}
      </div>
    </div>
  );
}
