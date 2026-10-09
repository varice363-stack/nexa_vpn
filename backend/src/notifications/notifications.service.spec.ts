import { NotificationsService } from './notifications.service';

/**
 * Широковещательные уведомления (userId = null): одна строка на всех, а
 * прочтение — у каждого своё (NotificationRead). Раньше флаг `read` был общим.
 */
const me = { id: 'u1' } as never;

function makePrisma(over: { notification?: object; notificationRead?: object } = {}) {
  return {
    notification: {
      findMany: jest.fn(async () => []),
      updateMany: jest.fn(async () => ({ count: 0 })),
      findFirst: jest.fn(async () => null),
      ...over.notification,
    },
    notificationRead: {
      upsert: jest.fn(async () => ({})),
      createMany: jest.fn(async () => ({ count: 0 })),
      ...over.notificationRead,
    },
  } as any;
}

describe('NotificationsService — широковещательные уведомления', () => {
  it('прочитал один пользователь — у другого уведомление остаётся непрочитанным', async () => {
    const mine = await new NotificationsService(
      makePrisma({
        notification: {
          findMany: jest.fn(async () => [{ id: 'b1', userId: null, read: false, reads: [{ userId: 'u1' }] }]),
        },
      }),
    ).forUser(me);
    expect(mine[0].read).toBe(true);

    const other = await new NotificationsService(
      makePrisma({
        notification: {
          findMany: jest.fn(async () => [{ id: 'b1', userId: null, read: false, reads: [] }]),
        },
      }),
    ).forUser({ id: 'u2' } as never);
    expect(other[0].read).toBe(false);
  });

  it('личное уведомление читается по собственному флагу, как и раньше', async () => {
    const rows = await new NotificationsService(
      makePrisma({
        notification: { findMany: jest.fn(async () => [{ id: 'p1', userId: 'u1', read: true, reads: [] }]) },
      }),
    ).forUser(me);
    expect(rows[0].read).toBe(true);
    expect(rows[0]).not.toHaveProperty('reads');
  });

  it('markRead широковещательного пишет отметку пользователя и не трогает общую строку', async () => {
    const prisma = makePrisma({ notification: { findFirst: jest.fn(async () => ({ id: 'b1' })) } });
    const res = await new NotificationsService(prisma).markRead(me, 'b1');

    expect(res).toEqual({ count: 1 });
    expect(prisma.notificationRead.upsert).toHaveBeenCalledWith(
      expect.objectContaining({ create: { userId: 'u1', notificationId: 'b1' } }),
    );
    // общая строка не обновлялась: updateMany искал только личные (userId = me)
    expect(prisma.notification.updateMany.mock.calls[0][0].where).toEqual({ id: 'b1', userId: 'u1' });
  });

  it('markRead чужого личного уведомления — 0 и никаких записей', async () => {
    const prisma = makePrisma();
    expect(await new NotificationsService(prisma).markRead(me, 'foreign')).toEqual({ count: 0 });
    expect(prisma.notificationRead.upsert).not.toHaveBeenCalled();
  });

  it('markAllRead отмечает только непрочитанные широковещательные', async () => {
    const prisma = makePrisma({
      notification: { findMany: jest.fn(async () => [{ id: 'b2' }, { id: 'b3' }]) },
    });
    const res = await new NotificationsService(prisma).markAllRead(me);

    expect(prisma.notificationRead.createMany).toHaveBeenCalledWith({
      data: [
        { userId: 'u1', notificationId: 'b2' },
        { userId: 'u1', notificationId: 'b3' },
      ],
      skipDuplicates: true,
    });
    expect(res.count).toBe(2);
  });
});
