import { NotFoundException } from '@nestjs/common';

import { PrismaService } from '../common/prisma/prisma.service';
import { BannersService } from './banners.service';

/** Minimal in-memory Prisma double for the banner table. */
function prismaMock(rows: Record<string, unknown>[] = []) {
  const store = [...rows];
  return {
    banner: {
      findMany: jest.fn(async (args?: any) => {
        let out = [...store];
        if (args?.where?.active !== undefined) {
          out = out.filter((r: any) => r.active === args.where.active);
        }
        if (args?.where?.placement) {
          out = out.filter((r: any) => r.placement === args.where.placement);
        }
        if (args?.select) {
          out = out.map((r: any) =>
            Object.fromEntries(
              Object.keys(args.select).map((k) => [k, r[k]]),
            ),
          );
        }
        return out;
      }),
      findUnique: jest.fn(
        async ({ where }: any) => store.find((r: any) => r.id === where.id) ?? null,
      ),
      update: jest.fn(async ({ where, data }: any) => {
        const row: any = store.find((r: any) => r.id === where.id);
        if (!row) throw new Error('Record to update not found.');
        for (const [k, v] of Object.entries<any>(data)) {
          row[k] = v && typeof v === 'object' && 'increment' in v
            ? row[k] + v.increment
            : v;
        }
        return row;
      }),
      create: jest.fn(async ({ data }: any) => {
        const row = { id: 'new-id', impressions: 0, clicks: 0, ...data };
        store.push(row);
        return row;
      }),
    },
    _store: store,
  };
}

describe('BannersService', () => {
  const seed = () => [
    {
      id: 'b1',
      title: 'Home promo',
      description: 'd',
      imageUrl: null,
      buttonText: 'Go',
      targetUrl: 'https://example.com',
      placement: 'home',
      sortOrder: 0,
      impressions: 100,
      clicks: 5,
      active: true,
    },
    {
      id: 'b2',
      title: 'Premium promo',
      description: 'd',
      imageUrl: null,
      buttonText: null,
      targetUrl: null,
      placement: 'premium',
      sortOrder: 0,
      impressions: 50,
      clicks: 0,
      active: true,
    },
    {
      id: 'b3',
      title: 'Disabled',
      description: 'd',
      imageUrl: null,
      buttonText: null,
      targetUrl: null,
      placement: 'home',
      sortOrder: 0,
      impressions: 0,
      clicks: 0,
      active: false,
    },
  ];

  function make(rows = seed()) {
    const prisma = prismaMock(rows);
    return {
      prisma,
      service: new BannersService(prisma as unknown as PrismaService),
    };
  }

  it('findActive returns only active banners', async () => {
    const { service } = make();
    const result = await service.findActive();
    expect(result).toHaveLength(2);
    expect(result.map((b: any) => b.id)).toEqual(['b1', 'b2']);
  });

  it('findActive filters by placement slot', async () => {
    const { service } = make();
    const result = await service.findActive('premium');
    expect(result).toHaveLength(1);
    expect((result[0] as any).id).toBe('b2');
  });

  it('findActive never exposes impression/click counters', async () => {
    const { service } = make();
    const [banner] = await service.findActive('home');
    expect(banner).not.toHaveProperty('impressions');
    expect(banner).not.toHaveProperty('clicks');
    expect(banner).toHaveProperty('targetUrl', 'https://example.com');
  });

  it('trackImpression increments the counter', async () => {
    const { service, prisma } = make();
    await service.trackImpression('b1');
    expect((prisma._store[0] as any).impressions).toBe(101);
  });

  it('trackClick increments the counter', async () => {
    const { service, prisma } = make();
    await service.trackClick('b1');
    expect((prisma._store[0] as any).clicks).toBe(6);
  });

  it('tracking a missing banner resolves quietly (never breaks the client)', async () => {
    const { service } = make();
    await expect(service.trackImpression('nope')).resolves.toBeUndefined();
    await expect(service.trackClick('nope')).resolves.toBeUndefined();
  });

  it('stats computes CTR per banner and in total', async () => {
    const { service } = make();
    const report = await service.stats();

    expect(report.totals.impressions).toBe(150);
    expect(report.totals.clicks).toBe(5);
    // 5 / 150 => 3.33 %
    expect(report.totals.ctr).toBeCloseTo(3.33, 2);

    const b1 = report.banners.find((b) => b.id === 'b1')!;
    expect(b1.ctr).toBe(5); // 5 / 100
    const b2 = report.banners.find((b) => b.id === 'b2')!;
    expect(b2.ctr).toBe(0); // no clicks
  });

  it('stats reports zero CTR when a banner was never shown', async () => {
    const { service } = make();
    const report = await service.stats();
    const b3 = report.banners.find((b) => b.id === 'b3')!;
    expect(b3.impressions).toBe(0);
    expect(b3.ctr).toBe(0);
  });

  it('resetStats zeroes both counters', async () => {
    const { service, prisma } = make();
    await service.resetStats('b1');
    expect((prisma._store[0] as any).impressions).toBe(0);
    expect((prisma._store[0] as any).clicks).toBe(0);
  });

  it('resetStats rejects an unknown banner', async () => {
    const { service } = make();
    await expect(service.resetStats('nope')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
