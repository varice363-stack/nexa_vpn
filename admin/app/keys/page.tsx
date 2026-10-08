'use client';

import PageHeader from '@/components/PageHeader';
import KeysManager from '@/components/KeysManager';

/**
 * Ключи доступа: та же панель управления ключами, что и на дашборде
 * (общий компонент KeysManager), но крупно — со списком, поиском и фильтрами.
 */
export default function KeysPage() {
  return (
    <div>
      <PageHeader
        title="Ключи доступа"
        subtitle="Выдать, продлить, изменить лимит трафика, отозвать или удалить ключ"
      />
      <KeysManager />
    </div>
  );
}
