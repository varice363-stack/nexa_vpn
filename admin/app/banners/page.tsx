'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';

import Badge from '@/components/Badge';
import Modal from '@/components/Modal';
import PageHeader from '@/components/PageHeader';
import { api } from '@/lib/api';
import { Banner } from '@/lib/types';

const EMPTY_FORM = { title: '', description: '', buttonText: '' };

export default function BannersPage() {
  const [banners, setBanners] = useState<Banner[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [form, setForm] = useState(EMPTY_FORM);

  const load = useCallback(async () => {
    setError(null);
    try {
      setBanners(await api<Banner[]>('/banners/all'));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load banners');
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function toggleActive(b: Banner) {
    await api(`/banners/${b.id}/${b.active ? 'deactivate' : 'activate'}`, { method: 'POST' });
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
      await api('/banners', { method: 'POST', body: JSON.stringify(form) });
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
        title="Banners"
        subtitle="Home screen promos"
        action={<button onClick={() => setModalOpen(true)} className="btn-primary">+ Create banner</button>}
      />

      {error ? <div className="text-sm text-rose-400 mb-3">{error}</div> : null}

      <div className="space-y-3">
        {banners.map((b) => (
          <div key={b.id} className="glass p-4 flex items-center gap-4">
            {b.imageUrl ? (
              <img src={b.imageUrl} alt="" className="w-24 h-14 object-cover rounded-lg" />
            ) : (
              <div className="w-24 h-14 rounded-lg bg-white/5 grid place-items-center text-faint text-xs">
                no image
              </div>
            )}
            <div className="flex-1">
              <div className="font-semibold text-text">{b.title}</div>
              <div className="text-xs text-muted mt-0.5 line-clamp-2">{b.description}</div>
              <div className="text-[11px] text-faint mt-1">
                {b.buttonText ?? 'no CTA'} · {new Date(b.createdAt).toLocaleDateString()}
              </div>
            </div>
            <Badge value={b.active ? 'ACTIVE' : 'DISABLED'} />
            <label className="text-xs text-muted cursor-pointer">
              Upload
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
              onClick={() => toggleActive(b)}
              className={`px-2.5 py-1 rounded-md text-xs font-medium border ${
                b.active
                  ? 'border-amber-400/40 text-amber-300'
                  : 'border-emerald-400/40 text-emerald-300'
              }`}
            >
              {b.active ? 'Deactivate' : 'Activate'}
            </button>
          </div>
        ))}
        {banners.length === 0 && !error ? (
          <div className="glass-card text-muted text-sm">No banners yet.</div>
        ) : null}
      </div>

      {modalOpen ? (
        <Modal title="Create banner" onClose={() => setModalOpen(false)}>
          <form onSubmit={createBanner} className="space-y-3">
            <input required placeholder="Title" value={form.title}
              onChange={(e) => setForm({ ...form, title: e.target.value })} className="input-base w-full" />
            <textarea required placeholder="Description" rows={3} value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })} className="input-base w-full" />
            <input placeholder="Button text (e.g. Upgrade now)" value={form.buttonText}
              onChange={(e) => setForm({ ...form, buttonText: e.target.value })} className="input-base w-full" />
            <button type="submit" className="btn-primary w-full">Create banner</button>
          </form>
        </Modal>
      ) : null}
    </div>
  );
}
