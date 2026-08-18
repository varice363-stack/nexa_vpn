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
      <PageHeader title="Access Keys" subtitle="All issued keys (provisioning)" />
      {error ? (
        <div className="glass-card text-rose-300 mb-3">{error}</div>
      ) : null}
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>User</th>
              <th>Name</th>
              <th>Protocol</th>
              <th>Status</th>
              <th>Assigned Server</th>
              <th>Server Status</th>
              <th>Device</th>
              <th>Created</th>
              <th>Expires</th>
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
          <div className="text-muted text-sm py-4">No access keys yet.</div>
        ) : null}
      </div>
    </div>
  );
}
