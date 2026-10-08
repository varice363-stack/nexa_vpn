'use client';

import { clearToken } from '@/lib/api';

/**
 * Экран сбоя панели вместо английского «Application error: a client-side
 * exception has occurred». Чаще всего такой сбой — это старый HTML в кэше
 * браузера (или вкладка, открытая до пересборки): ссылки на скрипты в нём уже
 * не существуют. Поэтому здесь сразу кнопка «Перезагрузить», а не пугающий
 * текст, и возможность выйти на страницу входа, если дело в сессии.
 */
export default function PanelError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="glass-card max-w-xl space-y-3">
      <h2 className="text-lg font-bold text-text">Панель не смогла загрузиться</h2>
      <p className="text-sm text-muted">
        Обычно это старая версия страницы в кэше браузера после обновления панели.
        Нажмите «Перезагрузить» — страница скачается заново и заработает.
      </p>
      {error?.message ? (
        <p className="text-xs text-faint break-all">Техническая деталь: {error.message}</p>
      ) : null}
      <div className="flex gap-3 pt-1">
        <button onClick={() => reset()} className="btn-primary">
          Перезагрузить
        </button>
        <button
          onClick={() => {
            clearToken();
            window.location.href = '/login';
          }}
          className="px-3 py-2 rounded-lg text-sm border border-white/15 text-muted"
        >
          Войти заново
        </button>
      </div>
    </div>
  );
}
