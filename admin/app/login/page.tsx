'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';

import { api, setToken } from '@/lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const result = await api<{ accessToken: string }>('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });
      setToken(result.accessToken);
      router.push('/dashboard');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen grid place-items-center">
      <form onSubmit={onSubmit} className="w-full max-w-sm glass-card space-y-4">
        <div className="text-center">
          <div className="w-12 h-12 mx-auto rounded-2xl bg-gradient-to-br from-accent to-indigo-500 grid place-items-center font-bold text-white text-xl">
            N
          </div>
          <h1 className="mt-3 text-xl font-bold">Админ-панель Nexa VPN</h1>
          <p className="text-sm text-muted">Войдите для управления сервисом</p>
        </div>
        <input
          type="email"
          required
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="input-base w-full"
        />
        <input
          type="password"
          required
          placeholder="Пароль"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="input-base w-full"
        />
        {error ? <div className="text-sm text-rose-400">{error}</div> : null}
        <button type="submit" disabled={loading} className="btn-primary w-full">
          {loading ? 'Вход…' : 'Войти'}
        </button>
        <p className="text-[11px] text-faint text-center">
          Админ по умолчанию: admin@nexavpn.app / admin1234
        </p>
      </form>
    </div>
  );
}
