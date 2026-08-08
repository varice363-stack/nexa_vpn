'use client';

import { useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';
import { Plan } from '@/lib/types';

export default function PlansPage() {
  const [plans, setPlans] = useState<Plan[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<Plan[]>('/plans')
      .then(setPlans)
      .catch((e) => setError(e.message));
  }, []);

  return (
    <div>
      <PageHeader title="Plans" subtitle="Subscription products (source of billing truth)" />
      {error ? <div className="glass-card text-rose-300 mb-3">{error}</div> : null}
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Name</th>
              <th>Code</th>
              <th>Duration</th>
              <th>Price</th>
              <th>Currency</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {plans.map((p) => (
              <tr key={p.id}>
                <td className="text-text font-medium">{p.name}</td>
                <td>{p.code}</td>
                <td>{p.durationDays} days</td>
                <td>${p.price.toFixed(2)}</td>
                <td>{p.currency}</td>
                <td><Badge value={p.isActive ? 'ACTIVE' : 'DISABLED'} /></td>
              </tr>
            ))}
          </tbody>
        </table>
        {plans.length === 0 && !error ? (
          <div className="text-muted text-sm py-4">No plans yet. Run the seed.</div>
        ) : null}
      </div>
    </div>
  );
}
