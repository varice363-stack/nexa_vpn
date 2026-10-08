import { NextResponse, type NextRequest } from 'next/server';

/**
 * Запрет кэширования HTML-страниц панели.
 *
 * Причина: Next.js отдаёт статически собранные страницы с заголовком
 * `Cache-Control: s-maxage=31536000, stale-while-revalidate` — то есть «год в
 * кэше». После каждой пересборки хэши JS-чанков меняются, а браузер/прокси мог
 * отдать старый HTML со ссылками на уже несуществующие файлы → в браузере
 * «Application error: a client-side exception has occurred», хотя на сервере
 * всё живо (проверено curl'ом: страница отвечает 200). Здесь HTML всегда
 * свежий, а /_next/static остаётся immutable-кэшем (файлы там с хэшем в имени).
 */
export function middleware(_req: NextRequest) {
  const res = NextResponse.next();
  res.headers.set('Cache-Control', 'no-store, must-revalidate');
  return res;
}

export const config = {
  // Всё, кроме неизменяемых ассетов сборки, API-прокси и картинок баннеров.
  matcher: ['/((?!_next/static|_next/image|api|uploads|favicon.ico).*)'],
};
