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
        title="Servers"
        subtitle={`${servers.length} locations`}
        action={<button onClick={() => setModalOpen(true)} className="btn-primary">+ Add server</button>}
      />

      {error ? <div className="text-sm text-rose-400 mb-3">{error}</div> : null}

      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Name</th>
              <th>Location</th>
              <th>IP</th>
              <th>Protocol</th>
              <th>Ping</th>
              <th>Load</th>
              <th>Tier</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {servers.map((s) => (
              <tr key={s.id}>
                <td className="text-text font-medium">{s.name}</td>
                <td>{s.city}, {s.country}</td>
                <td className="font-mono text-xs">{s.ip}</td>
                <td>{s.protocol}</td>
                <td>{s.ping} ms</td>
                <td>{Math.round(s.load * 100)}%</td>
                <td>{s.premium ? <Badge value="PREMIUM" /> : 'Free'}</td>
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
                    {s.status === 'ACTIVE' ? 'Disable' : 'Enable'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {modalOpen ? (
        <Modal title="Add server" onClose={() => setModalOpen(false)}>
          <form onSubmit={createServer} className="space-y-3">
            <input required placeholder="Name (e.g. Istanbul TR-01)" value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })} className="input-base w-full" />
            <div className="grid grid-cols-2 gap-3">
              <input required placeholder="Country" value={form.country}
                onChange={(e) => setForm({ ...form, country: e.target.value })} className="input-base" />
              <input required placeholder="Code (TR)" maxLength={2} value={form.countryCode}
                onChange={(e) => setForm({ ...form, countryCode: e.target.value.toUpperCase() })} className="input-base" />
              <input required placeholder="City" value={form.city}
                onChange={(e) => setForm({ ...form, city: e.target.value })} className="input-base" />
              <input required placeholder="IP address" value={form.ip}
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
              Premium-only server
            </label>
            <button type="submit" className="btn-primary w-full">Create server</button>
          </form>
        </Modal>
      ) : null}
    </div>
  );
}
