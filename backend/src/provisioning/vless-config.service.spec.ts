import { VlessConfigService } from './vless-config.service';
import {
  toXrayIngressConfig,
  validateIngressConfig,
  XrayIngressConfig,
} from './xray-ingress.config';

const key = { uuid: '11111111-2222-3333-4444-555555555555', name: 'My iPhone' };

const tcpConfig: XrayIngressConfig = {
  host: '185.65.134.22',
  port: 443,
  transport: 'tcp',
  security: 'none',
  sni: null,
  flow: null,
  publicKey: null,
  shortId: null,
};

describe('VlessConfigService (TASK #012 — ingress contract)', () => {
  const service = new VlessConfigService();

  it('produces a valid vless:// URI for a valid ingress config', () => {
    const uri = service.generateUri(key, tcpConfig);
    expect(uri).toMatch(/^vless:\/\//);
    expect(uri).toContain(`${key.uuid}@185.65.134.22:443`);
    expect(uri).toContain('encryption=none');
    expect(uri).toContain('type=tcp');
    expect(uri).toContain('security=none');
  });

  it('encodes the remark (name) as the fragment', () => {
    expect(service.generateUri(key, tcpConfig)).toContain('#My%20iPhone');
  });

  it('returns null when a mandatory parameter is missing (no fake URI)', () => {
    expect(service.generateUri(key, { ...tcpConfig, port: 0 })).toBeNull();
    expect(service.generateUri(key, { ...tcpConfig, transport: '' })).toBeNull();
    expect(service.generateUri(key, { ...tcpConfig, security: '' })).toBeNull();
  });

  it('uses the server-specific parameters (not placeholders) when present', () => {
    const uri = service.generateUri(key, {
      host: '10.0.0.1',
      port: 8443,
      transport: 'ws',
      security: 'tls',
      sni: 'cdn.nexa.app',
      flow: null,
      publicKey: null,
      shortId: null,
    });
    expect(uri).toContain('@10.0.0.1:8443');
    expect(uri).toContain('type=ws');
    expect(uri).toContain('security=tls');
    expect(uri).toContain('sni=cdn.nexa.app');
  });

  it('appends reality parameters (flow/pbk/sid) when present', () => {
    const uri = service.generateUri(key, {
      host: '10.0.0.2',
      port: 443,
      transport: 'tcp',
      security: 'reality',
      sni: 'yahoo.com',
      flow: 'xtls-rprx-vision',
      publicKey: 'REALITY_PUBLIC_KEY',
      shortId: 'abcdef',
    });
    expect(uri).toContain('security=reality');
    expect(uri).toContain('flow=xtls-rprx-vision');
    expect(uri).toContain('pbk=REALITY_PUBLIC_KEY');
    expect(uri).toContain('sid=abcdef');
  });

  it('qrPayload equals the full URI (client renders QR)', () => {
    expect(service.qrPayload(key, tcpConfig)).toBe(service.generateUri(key, tcpConfig));
  });

  it('contains no unexpected secrets or credentials', () => {
    const uri = service.generateUri(key, tcpConfig)!;
    expect(uri).not.toContain('password');
    expect(uri).not.toContain('private');
    expect(uri).not.toContain('PAYMENT_');
  });
});

describe('XrayIngressConfig validation (TASK #012)', () => {
  it('valid config passes', () => {
    expect(validateIngressConfig(tcpConfig).valid).toBe(true);
  });

  it('missing host → invalid', () => {
    expect(validateIngressConfig({ ...tcpConfig, host: '' }).valid).toBe(false);
  });

  it('missing port → invalid', () => {
    expect(validateIngressConfig({ ...tcpConfig, port: 0 }).valid).toBe(false);
  });

  it('missing security parameter → invalid', () => {
    expect(validateIngressConfig({ ...tcpConfig, security: '' }).valid).toBe(false);
  });

  it('tls requires sni', () => {
    const cfg = { ...tcpConfig, security: 'tls', sni: null };
    const result = validateIngressConfig(cfg);
    expect(result.valid).toBe(false);
    expect(result.reason).toContain('sni');
  });

  it('reality requires sni and publicKey', () => {
    const noKey = {
      ...tcpConfig,
      security: 'reality',
      sni: 'yahoo.com',
      publicKey: null,
    };
    expect(validateIngressConfig(noKey).valid).toBe(false);

    const ok = { ...noKey, publicKey: 'PUBLIC_KEY' };
    expect(validateIngressConfig(ok).valid).toBe(true);
  });

  it('toXrayIngressConfig maps VpnServer fields onto the contract', () => {
    const mapped = toXrayIngressConfig({
      ip: '1.2.3.4',
      port: 8443,
      transport: 'ws',
      security: 'tls',
      sni: 'cdn.nexa.app',
      flow: 'xtls-rprx-vision',
      publicKey: 'PBK',
      shortId: 'SID',
    } as never);
    expect(mapped).toMatchObject({
      host: '1.2.3.4',
      port: 8443,
      transport: 'ws',
      security: 'tls',
      sni: 'cdn.nexa.app',
      flow: 'xtls-rprx-vision',
      publicKey: 'PBK',
      shortId: 'SID',
    });
  });
});
