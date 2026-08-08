import type { Metadata } from 'next';

import Sidebar from '@/components/Sidebar';
import './globals.css';

export const metadata: Metadata = {
  title: 'Nexa VPN Admin',
  description: 'Nexa VPN administration panel',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body>
        <div className="flex min-h-screen">
          <Sidebar />
          <main className="flex-1 p-8 overflow-y-auto">{children}</main>
        </div>
      </body>
    </html>
  );
}
