'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import Modal from '@/components/Modal';
import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';
import { Banner, BannerPlacement, BannerStats } from '@/lib/types';

const EMPTY_FORM = {
  title: '',
  description: '',
  buttonText: '',
  targetUrl: '',
  placement: 'home' as BannerPlacement,
  sortOrder: '0',
};

const PLACEMENTS: { value: BannerPlacement; label: string }[] = [
  { value: 'home', label: 'Главный экран' },
  { value: 'premium', label: 'Экран Premium' },
];

function ctr(impressions: number, clicks: number): string {
  if (impressions === 0) return '—';
  return `${((clicks / impressions) * 100).toFixed(2)}%`;
}

export default function BannersPage() {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [stats, setStats] = useState<BannerStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [list, s] = await Promise.all([
        api<Banner[]>('/banners/all'),
        api<BannerStats>('/banners/stats'),
      ]);
      setBanners(list);
      setStats(s);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Не удалось загрузить баннеры');
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function toggleActive(b: Banner) {
    await api(`/banners/${b.id}/${b.active ? 'deactivate' : 'activate'}`, { method: 'POST' });
    load();
  }

  async function resetStats(b: Banner) {
    if (!confirm(`Сбросить просмотры и клики для "${b.title}"?`)) return;
    await api(`/banners/${b.id}/reset-stats`, { method: 'POST' });
    load();
  }

  async function uploadImage(b: Banner, file: File) {
    const formData = new FormData();
    formData.append('file', file);
    const token = localStorage.getItem('nexa_admin_token');
    await fetch(
      `${process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3000/api'}/banners/${b.id}/upload`,
      {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: formData,
      },
    );
    load();
  }

  async function createBanner(e: FormEvent) {
    e.preventDefault();
    try {
      // Only send optional fields when filled — the API validates
      // targetUrl as a real http(s) URL and rejects empty strings.
      const payload: Record<string, unknown> = {
        title: form.title,
        description: form.description,
        placement: form.placement,
        sortOrder: Number(form.sortOrder) || 0,
      };
      if (form.buttonText.trim()) payload.buttonText = form.buttonText.trim();
      if (form.targetUrl.trim()) payload.targetUrl = form.targetUrl.trim();

      await api('/banners', { method: 'POST', body: JSON.stringify(payload) });
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
        title="Баннеры"
        subtitle="Промо-слоты на главном экране и Premium"
        action={<button onClick={() => setModalOpen(true)} className="btn-primary">+ Создать баннер</button>}
      />

      {error ? <div className="text-sm text-rose-400 mb-3">{error}</div> : null}

      {stats ? (
        <div className="grid grid-cols-3 gap-3 mb-4">
          <div className="glass p-4">
            <div className="text-xs text-muted">Всего показов</div>
            <div className="text-2xl font-semibold text-text mt-1">
              {stats.totals.impressions.toLocaleString()}
            </div>
          </div>
          <div className="glass p-4">
            <div className="text-xs text-muted">Всего кликов</div>
            <div className="text-2xl font-semibold text-text mt-1">
              {stats.totals.clicks.toLocaleString()}
            </div>
          </div>
          <div className="glass p-4">
            <div className="text-xs text-muted">Средний CTR</div>
            <div className="text-2xl font-semibold text-text mt-1">
              {stats.totals.ctr}%
            </div>
          </div>
        </div>
      ) : null}

      <div className="space-y-3">
        {banners.map((b) => (
          <div key={b.id} className="glass p-4 flex items-center gap-4">
            {b.imageUrl ? (
              <img src={b.imageUrl} alt="" className="w-24 h-14 object-cover rounded-lg" />
            ) : (
              <div className="w-24 h-14 rounded-lg bg-white/5 grid place-items-center text-faint text-xs">
                нет изображения
              </div>
            )}
            <div className="flex-1 min-w-0">
              <div className="font-semibold text-text flex items-center gap-2">
                {b.title}
                <span className="text-[10px] uppercase tracking-wide px-1.5 py-0.5 rounded bg-white/5 text-muted">
                  {b.placement}
                </span>
              </div>
              <div className="text-xs text-muted mt-0.5 line-clamp-2">{b.description}</div>
              <div className="text-[11px] text-faint mt-1 truncate">
                {b.buttonText ?? 'no CTA'}
                {b.targetUrl ? ` → ${b.targetUrl}` : ' → /premium'}
                {' · '}#{b.sortOrder}
                {' · '}{new Date(b.createdAt).toLocaleDateString()}
              </div>
            </div>

            <div className="text-right shrink-0 w-28">
              <div className="text-[11px] text-muted">
                {b.impressions.toLocaleString()} показов
              </div>
              <div className="text-[11px] text-muted">
                {b.clicks.toLocaleString()} кликов
              </div>
              <div className="text-sm font-semibold text-text mt-0.5">
                CTR {ctr(b.impressions, b.clicks)}
              </div>
            </div>

            <Badge value={b.active ? 'ACTIVE' : 'DISABLED'} />
            <label className="text-xs text-muted cursor-pointer">
              Загрузить
              <input
                type="file"
                accept="image/*"
                className="hidden"
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) uploadImage(b, file);
                }}
              />
            </label>
            <button
              onClick={() => resetStats(b)}
              className="px-2.5 py-1 rounded-md text-xs font-medium border border-white/15 text-muted"
            >
              Сбросить
            </button>
            <button
              onClick={() => toggleActive(b)}
              className={`px-2.5 py-1 rounded-md text-xs font-medium border ${
                b.active
                  ? 'border-amber-400/40 text-amber-300'
                  : 'border-emerald-400/40 text-emerald-300'
              }`}
            >
              {b.active ? 'Отключить' : 'Включить'}
            </button>
          </div>
        ))}
        {banners.length === 0 && !error ? (
          <div className="glass-card text-muted text-sm">No banners yet.</div>
        ) : null}
      </div>

      {modalOpen ? (
        <Modal title="Создать баннер" onClose={() => setModalOpen(false)}>
          <form onSubmit={createBanner} className="space-y-3">
            <input required placeholder="Заголовок" value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })} className="input-base w-full" />
            <textarea required placeholder="Описание" rows={3} value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })} className="input-base w-full" />
            <input placeholder="Текст кнопки (например: Получить сейчас)" value={form.buttonText}
              onChange={(e) => setForm({ ...form, buttonText: e.target.value })} className="input-base w-full" />
            <input
              type="url"
              placeholder="Ссылка (https://… — пусто открывает Premium)"
              value={form.targetUrl}
              onChange={(e) => setForm({ ...form, targetUrl: e.target.value })}
              className="input-base w-full"
            />
            <div className="flex gap-3">
              <select
                value={form.placement}
                onChange={(e) =>
                  setForm({ ...form, placement: e.target.value as BannerPlacement })
                }
                className="input-base w-full"
              >
                {PLACEMENTS.map((p) => (
                  <option key={p.value} value={p.value}>{p.label}</option>
                ))}
              </select>
              <input
                type="number"
                min={0}
                placeholder="Порядок сортировки"
                value={form.sortOrder}
                onChange={(e) => setForm({ ...form, sortOrder: e.target.value })}
                className="input-base w-full"
              />
            </div>
            <button type="submit" className="btn-primary w-full">Создать баннер</button>
          </form>
        </Modal>
      ) : null}
    </div>
  );
}
