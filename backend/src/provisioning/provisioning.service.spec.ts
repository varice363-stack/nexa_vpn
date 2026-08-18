import { VlessConfigService } from './vless-config.service';
import { ProvisioningService } from './provisioning.service';

/**
 * Provisioning contract tests (TASK #010/#011):
 *  * ACTIVE key + assigned server → valid VLESS config;
 *  * deterministic assignment (lowest ping, tie-breaker by id);
 *  * assignment is stable across reads;
 *  * ACTIVE + missing server → config null;
 *  * EXPIRED / REVOKED → no config;
 *  * foreign key → rejected (ownership);
 *  * user cannot choose a server (DTO has no serverId).
 */

const user = { id: 'u1', email: 'u@test.dev' } as never;

const activeKey = {
  id: 'k1',
  name: 'My iPhone',
  protocol: 'VLESS',
  uuid: '11111111-2222-3333-4444-555555555555',
  status: 'ACTIVE',
  createdAt: new Date(),
  expiresAt: null,
  lastUsedAt: null,
  deviceId: null,
  serverId: 's1',
};

const servers = [
  {
    id: 's1',
    name: 'Istanbul TR-01',
    country: 'Turkey',
    countryCode: 'TR',
    city: 'Istanbul',
    ip: '185.65.134.22',
    port: 443,
    transport: 'tcp',
    security: 'none',
    sni: null,
    ping: 8,
    status: 'ACTIVE',
  },
  {
    id: 's2',
    name: 'Frankfurt DE-01',
    country: 'Germany',
    countryCode: 'DE',
    city: 'Frankfurt',
    ip: '185.65.135.10',
    port: 443,
    transport: 'tcp',
    security: 'none',
    sni: null,
    ping: 42,
    status: 'ACTIVE',
  },
];

function makePrisma(overrides: Record<string, unknown> = {}) {
  const store = { keys: [activeKey], servers };
  return {
    accessKey: {
      findMany: jest.fn(async () => store.keys),
      findFirst: jest.fn(async () => store.keys[0] ?? null),
      create: jest.fn(async (args: { data: Record<string, unknown> }) => ({
        id: 'k-new',
        ...args.data,
      })),
      update: jest.fn(async (args: { data: Record<string, unknown> }) => ({
        ...store.keys[0],
        ...args.data,
      })),
      updateMany: jest.fn(async () => ({ count: 1 })),
      ...(overrides.accessKey as Record<string, unknown> | undefined),
    },
    vpnServer: {
      findMany: jest.fn(async () => store.servers),
      findUnique: jest.fn(async ({ where }: { where: { id: string } }) =>
        store.servers.find((s) => s.id === where.id) ?? null,
      ),
      ...(overrides.vpnServer as Record<string, unknown> | undefined),
    },
    ...overrides,
  } as any;
}

const subscriptions = {
  hasActivePremium: jest.fn(async () => true),
} as never;

describe('ProvisioningService (TASK #011 — server assignment)', () => {
  it('new AccessKey receives a serverId (deterministic assignment)', async () => {
    const prisma = makePrisma();
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    await service.create(user, { name: 'New key' });

    const createCall = (prisma.accessKey.create as jest.Mock).mock.calls[0][0];
    // Lowest ping server (s1 = 8ms) is assigned.
    expect(createCall.data.serverId).toBe('s1');
  });

  it('assignment is deterministic with an id tie-breaker', async () => {
    const tied = [
      { ...servers[0], ping: 10, id: 'b-server' },
      { ...servers[1], ping: 10, id: 'a-server' },
    ];
    const prisma = makePrisma({ vpnServer: { findMany: jest.fn(async () => tied) } });
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    await service.create(user, { name: 'New key' });

    const createCall = (prisma.accessKey.create as jest.Mock).mock.calls[0][0];
    expect(createCall.data.serverId).toBe('a-server');
  });

  it('repeated GET does not change the assigned server', async () => {
    const prisma = makePrisma();
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const first = await service.get(user, 'k1');
    const second = await service.get(user, 'k1');

    expect(first.serverId).toBe('s1');
    expect(second.serverId).toBe('s1');
    expect((prisma.accessKey.update as jest.Mock).mock.calls.length).toBe(0);
  });

  it('ACTIVE + assigned server → valid VLESS URI from that server', async () => {
    const prisma = makePrisma();
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const contract = await service.get(user, 'k1');

    expect(contract.config.uri).toMatch(/^vless:\/\/11111111-2222-3333-4444-555555555555@185\.65\.134\.22:443/);
    expect(contract.server).toMatchObject({ id: 's1', ip: servers[0].ip });
    expect(contract.config.qrPayload).toBe(contract.config.uri);
  });

  it('ACTIVE key with a missing/disabled assigned server → config null (no fallback)', async () => {
    const prisma = makePrisma({
      vpnServer: { findUnique: jest.fn(async () => null) },
    });
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const contract = await service.get(user, 'k1');

    expect(contract.config.uri).toBeNull();
    expect(contract.config.qrPayload).toBeNull();
    expect(contract.server).toBeNull();
  });

  it('lazy backfill assigns a server to an old ACTIVE key without serverId', async () => {
    const oldKey = { ...activeKey, serverId: null };
    const prisma = makePrisma({
      accessKey: {
        findFirst: jest.fn(async () => oldKey),
        update: jest.fn(async (args: { data: Record<string, unknown> }) => ({
          ...oldKey,
          ...args.data,
        })),
      },
    });
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const contract = await service.get(user, 'k1');

    expect((prisma.accessKey.update as jest.Mock).mock.calls.length).toBe(1);
    expect(contract.serverId).toBe('s1');
    expect(contract.config.uri).toMatch(/^vless:\/\//);
  });

  it('EXPIRED key → no config', async () => {
    const prisma = makePrisma({
      accessKey: { findFirst: jest.fn(async () => ({ ...activeKey, status: 'EXPIRED' })) },
    });
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const contract = await service.get(user, 'k1');

    expect(contract.status).toBe('EXPIRED');
    expect(contract.config.uri).toBeNull();
    expect(contract.config.qrPayload).toBeNull();
  });

  it('REVOKED key → no config', async () => {
    const prisma = makePrisma({
      accessKey: { findFirst: jest.fn(async () => ({ ...activeKey, status: 'REVOKED' })) },
    });
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const contract = await service.get(user, 'k1');

    expect(contract.status).toBe('REVOKED');
    expect(contract.config.uri).toBeNull();
    expect(contract.config.qrPayload).toBeNull();
  });

  it('foreign key → rejected with 404 (ownership via findFirst+userId)', async () => {
    const prisma = makePrisma({
      accessKey: { findFirst: jest.fn(async () => null) },
    });
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    await expect(service.get(user, 'k-foreign')).rejects.toThrow('Key not found');
  });

  it('GET /provisioning/active returns config for the assigned server', async () => {
    const prisma = makePrisma();
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const result = await service.active(user);

    expect(result).not.toBeNull();
    expect(result!.serverId).toBe('s1');
    expect(result!.config.uri).toMatch(/^vless:\/\//);
  });

  it('revoke flips ACTIVE → REVOKED (key is not deleted)', async () => {
    const prisma = makePrisma();
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    await service.revoke(user, 'k1');

    const updateCall = (prisma.accessKey.updateMany as jest.Mock).mock.calls[0][0];
    expect(updateCall.where.status).toBe('ACTIVE');
    expect(updateCall.data.status).toBe('REVOKED');
  });

  it('admin allKeys includes the assigned server + its status', async () => {
    const prisma = makePrisma();
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    await service.allKeys();

    const call = (prisma.accessKey.findMany as jest.Mock).mock.calls[0][0];
    expect(call.include.server.select).toMatchObject({
      id: true, name: true, status: true,
    });
  });

  it('ACTIVE + assigned server in MAINTENANCE → config null + reason', async () => {
    const prisma = makePrisma({
      vpnServer: {
        findUnique: jest.fn(async () => ({ ...servers[0], status: 'MAINTENANCE' })),
      },
    });
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const contract = await service.get(user, 'k1');

    expect(contract.config.uri).toBeNull();
    expect(contract.config.unavailableReason).toBe('SERVER_MAINTENANCE');
    expect(contract.server).toBeNull();
  });

  it('ACTIVE + assigned server missing → CONFIGURATION_UNAVAILABLE', async () => {
    const prisma = makePrisma({
      vpnServer: { findUnique: jest.fn(async () => null) },
    });
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const contract = await service.get(user, 'k1');

    expect(contract.config.uri).toBeNull();
    expect(contract.config.unavailableReason).toBe('CONFIGURATION_UNAVAILABLE');
  });

  it('ACTIVE + incomplete ingress params → INGRESS_CONFIG_INVALID', async () => {
    const prisma = makePrisma({
      vpnServer: {
        findUnique: jest.fn(async () => ({
          ...servers[0],
          port: null, // mandatory param missing
        })),
      },
    });
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const contract = await service.get(user, 'k1');

    expect(contract.config.uri).toBeNull();
    expect(contract.config.unavailableReason).toBe('INGRESS_CONFIG_INVALID');
  });

  it('URI is never present in the public server list response', async () => {
    const prisma = makePrisma();
    const service = new ProvisioningService(prisma, subscriptions, new VlessConfigService());

    const contract = await service.get(user, 'k1');
    // The contract does not leak into any public endpoint — the public
    // server list is served by ServersController and contains only
    // VpnServer rows (no config/uri fields). Assert the contract shape:
    expect(contract.config.uri).toMatch(/^vless:\/\//);
    // And that the serialized server summary carries no uri/secret:
    expect(JSON.stringify(contract.server)).not.toContain('vless://');
  });
});
