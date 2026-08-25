'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import Modal from '@/components/Modal';
import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';
import { ServerProtocol, VpnServer } from '@/lib/types';

const EMPTY_FORM = {
  name: '',
  country: '',
  countryCode: '',
  city: '',
  ip: '',
  protocol: 'WIREGUARD' as ServerProtocol,
  premium: false,
};

export default function ServersPage() {
  const [servers, setServers] = useState<VpnServer[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);

  const load = useCallback(async () => {
    setError(null);
    try {
      setServers(await api<VpnServer[]>('/servers/all'));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load servers');
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function toggleStatus(s: VpnServer) {
    await api(`/servers/${s.id}/${s.status === 'ACTIVE' ? 'disable' : 'enable'}`, {
      method: 'POST',
    });
    load();
  }

  async function createServer(e: FormEvent) {
    e.preventDefault();
    try {
      await api('/servers', { method: 'POST', body: JSON.stringify(form) });
      setModalOpen(false);
      setForm(EMPTY_FORM);
      load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Create failed');
    }
  }

  return (
    <div>
      <PageHeader
        title="Серверы"
        subtitle={`${servers.length} локаций`}
        action={<button onClick={() => setModalOpen(true)} className="btn-primary">+ Добавить сервер</button>}
      />

      {error ? <div className="text-sm text-rose-400 mb-3">{error}</div> : null}

      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Название</th>
              <th>Локация</th>
              <th>IP</th>
              <th>Протокол</th>
              <th>Пинг</th>
              <th>Загрузка</th>
              <th>Тариф</th>
              <th>Статус</th>
              <th>Действия</th>
            </tr>
          </thead>
          <tbody>
            {servers.map((s) => (
              <tr key={s.id}>
                <td className="text-text font-medium">{s.name}</td>
                <td>{s.city}, {s.country}</td>
                <td className="font-mono text-xs">{s.ip}</td>
                <td>{s.protocol}</td>
                <td>{s.ping} мс</td>
                <td>{Math.round(s.load * 100)}%</td>
                <td>{s.premium ? <Badge value="PREMIUM" /> : 'Бесплатный'}</td>
                <td><Badge value={s.status} /></td>
                <td>
                  <button
                    onClick={() => toggleStatus(s)}
                    className={`px-2.5 py-1 rounded-md text-xs font-medium border ${
                      s.status === 'ACTIVE'
                        ? 'border-rose-400/40 text-rose-300'
                        : 'border-emerald-400/40 text-emerald-300'
                    }`}
                  >
                    {s.status === 'ACTIVE' ? 'Отключить' : 'Включить'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {modalOpen ? (
        <Modal title="Добавить сервер" onClose={() => setModalOpen(false)}>
          <form onSubmit={createServer} className="space-y-3">
            <input required placeholder="Название (например: Istanbul TR-01)" value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })} className="input-base w-full" />
            <div className="grid grid-cols-2 gap-3">
              <input required placeholder="Страна" value={form.country}
                onChange={(e) => setForm({ ...form, country: e.target.value })} className="input-base" />
              <input required placeholder="Код (TR)" maxLength={2} value={form.countryCode}
                onChange={(e) => setForm({ ...form, countryCode: e.target.value.toUpperCase() })} className="input-base" />
              <input required placeholder="Город" value={form.city}
                onChange={(e) => setForm({ ...form, city: e.target.value })} className="input-base" />
              <input required placeholder="IP адрес" value={form.ip}
                onChange={(e) => setForm({ ...form, ip: e.target.value })} className="input-base" />
            </div>
            <select value={form.protocol}
              onChange={(e) => setForm({ ...form, protocol: e.target.value as ServerProtocol })}
              className="input-base w-full">
              <option value="WIREGUARD">WireGuard</option>
              <option value="OPENVPN">OpenVPN</option>
              <option value="IKEV2">IKEv2</option>
            </select>
            <label className="flex items-center gap-2 text-sm text-muted">
              <input type="checkbox" checked={form.premium}
                onChange={(e) => setForm({ ...form, premium: e.target.checked })} />
              Только для Premium-пользователей
            </label>
            <button type="submit" className="btn-primary w-full">Создать сервер</button>
          </form>
        </Modal>
      ) : null}
    </div>
  );
}
