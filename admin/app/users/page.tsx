'use client';

import { useCallback, useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';
import { Paginated, SubscriptionPlan, User } from '@/lib/types';

export default function UsersPage() {
  const [users, setUsers] = useState<User[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setError(null);
    try {
      const res = await api<Paginated<User>>(
        `/users?search=${encodeURIComponent(query)}&page=${page}&pageSize=20`,
      );
      setUsers(res.items);
      setTotal(res.total);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load users');
    }
  }, [query, page]);

  useEffect(() => {
    load();
  }, [load]);

  async function toggleBlock(user: User) {
    await api(`/users/${user.id}/${user.status === 'BLOCKED' ? 'unblock' : 'block'}`, {
      method: 'POST',
    });
    load();
  }

  async function assignPremium(user: User, plan: SubscriptionPlan) {
    await api(`/users/${user.id}/premium`, {
      method: 'POST',
      body: JSON.stringify({ plan }),
    });
    load();
  }

  return (
    <div>
      <PageHeader title="Users" subtitle={`${total} registered`} />
      <form
        className="flex gap-3 mb-4"
        onSubmit={(e) => {
          e.preventDefault();
          setPage(1);
          setQuery(search);
        }}
      >
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by email…"
          className="input-base flex-1"
        />
        <button type="submit" className="btn-primary">Search</button>
      </form>

      {error ? <div className="text-sm text-rose-400 mb-3">{error}</div> : null}

      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Email</th>
              <th>Role</th>
              <th>Status</th>
              <th>Country</th>
              <th>Last login</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id}>
                <td className="text-text font-medium">{u.email}</td>
                <td><Badge value={u.role} /></td>
                <td><Badge value={u.status} /></td>
                <td>{u.country ?? '—'}</td>
                <td>{u.lastLogin ? new Date(u.lastLogin).toLocaleDateString() : '—'}</td>
                <td className="space-x-2">
                  <button
                    onClick={() => toggleBlock(u)}
                    className={`px-2.5 py-1 rounded-md text-xs font-medium border ${
                      u.status === 'BLOCKED'
                        ? 'border-emerald-400/40 text-emerald-300'
                        : 'border-rose-400/40 text-rose-300'
                    }`}
                  >
                    {u.status === 'BLOCKED' ? 'Unblock' : 'Block'}
                  </button>
                  <select
                    defaultValue=""
                    onChange={(e) => {
                      if (e.target.value) {
                        assignPremium(u, e.target.value as SubscriptionPlan);
                        e.target.value = '';
                      }
                    }}
                    className="input-base text-xs py-1"
                  >
                    <option value="" disabled>Assign premium…</option>
                    <option value="MONTHLY">Monthly</option>
                    <option value="YEARLY">Yearly</option>
                    <option value="LIFETIME">Lifetime</option>
                  </select>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="flex items-center gap-3 mt-4">
        <button
          disabled={page <= 1}
          onClick={() => setPage(page - 1)}
          className="btn-ghost disabled:opacity-40"
        >
          ← Prev
        </button>
        <span className="text-sm text-muted">Page {page}</span>
        <button
          disabled={page * 20 >= total}
          onClick={() => setPage(page + 1)}
          className="btn-ghost disabled:opacity-40"
        >
          Next →
        </button>
      </div>
    </div>
  );
}
