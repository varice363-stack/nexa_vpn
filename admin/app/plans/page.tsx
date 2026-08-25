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
      <PageHeader title="Тарифы" subtitle="Подписки и цены" />
      {error ? <div className="glass-card text-rose-300 mb-3">{error}</div> : null}
      <div className="glass p-4">
        <table className="table-base">
          <thead>
            <tr>
              <th>Название</th>
              <th>Код</th>
              <th>Длительность</th>
              <th>Цена</th>
              <th>Валюта</th>
              <th>Статус</th>
            </tr>
          </thead>
          <tbody>
            {plans.map((p) => (
              <tr key={p.id}>
                <td className="text-text font-medium">{p.name}</td>
                <td>{p.code}</td>
                <td>{p.durationDays} дней</td>
                <td>{p.price.toFixed(2)}</td>
                <td>{p.currency}</td>
                <td><Badge value={p.isActive ? 'ACTIVE' : 'DISABLED'} /></td>
              </tr>
            ))}
          </tbody>
        </table>
        {plans.length === 0 && !error ? (
          <div className="text-muted text-sm py-4">Тарифов пока нет. Запустите seed.</div>
        ) : null}
      </div>
    </div>
  );
}
