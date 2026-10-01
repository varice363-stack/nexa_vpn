import { VpnServer } from '@prisma/client';

/**
 * Provider-independent Xray ingress configuration contract.
 *
 * Describes everything required to build a client-side VLESS URI from a
 * node. Secrets (privateKey, API tokens) are NEVER part of this contract —
 * they live in the env/config layer of the ingress deployment.
 *
 * Defaulting policy (TASK #028):
 *  * a *sane transport default* may be filled in here (port 443, tcp,
 *    security=reality) — it is not key material and every client expects it;
 *  * SNI/flow get safe defaults, because a Reality handshake with a SNI the
 *    node certificate cannot answer for fails TLS validation on the client
 *    (`x509: certificate is valid for *.telegram.org, not dl.google.com`);
 *  * **key material (pbk/sid) is NEVER defaulted from source code** — a
 *    hardcoded public key silently produces URIs that point at a node we do
 *    not control, and every client then fails at TLS instead of the admin
 *    seeing "configuration unavailable". Missing publicKey must surface.
 *    Operators who want a fleet-wide default set XRAY_REALITY_PUBLIC_KEY /
 *    XRAY_REALITY_SHORT_ID in the environment; per-node DB values always win.
 */
export interface XrayIngressConfig {
  host: string;
  port: number;
  transport: string;
  security: string;
  sni?: string | null;
  flow?: string | null;
  publicKey?: string | null;
  shortId?: string | null;
}

export interface IngressValidationResult {
  valid: boolean;
  reason?: string;
}

/** SNI the Marzban REALITY inbound actually presents a certificate for. */
const DEFAULT_SNI = process.env.XRAY_DEFAULT_SNI?.trim() || 'telegram.org';
const DEFAULT_FLOW = process.env.XRAY_DEFAULT_FLOW?.trim() || 'xtls-rprx-vision';
/** Legacy bad value left in some DB rows by an earlier migration/seed. */
const BROKEN_SNI = 'dl.google.com';

const trim = (value: string | null | undefined): string | null => {
  const v = value?.trim();
  return v ? v : null;
};

/** Maps a persisted VpnServer onto the ingress contract. */
export function toXrayIngressConfig(
  server: Pick<
    VpnServer,
    'ip' | 'port' | 'transport' | 'security' | 'sni' | 'flow' | 'publicKey' | 'shortId'
  >,
): XrayIngressConfig {
  const security = (trim(server.security) ?? 'reality').toLowerCase();
  const reality = security === 'reality';

  let sni = trim(server.sni);
  if (!sni || sni === BROKEN_SNI) {
    // Reality needs an SNI whose certificate the node can fake; a bare-IP
    // non-TLS inbound does not need one at all.
    sni = reality ? DEFAULT_SNI : null;
  }

  return {
    host: trim(server.ip) ?? 'morokvpn.com',
    port: server.port ?? 443,
    transport: trim(server.transport) ?? 'tcp',
    security,
    sni,
    flow: reality ? trim(server.flow) ?? DEFAULT_FLOW : trim(server.flow),
    publicKey: trim(server.publicKey) ?? trim(process.env.XRAY_REALITY_PUBLIC_KEY),
    shortId: trim(server.shortId) ?? trim(process.env.XRAY_REALITY_SHORT_ID),
  };
}

/**
 * Validates an ingress config BEFORE URI generation.
 *
 * Mandatory for any scheme: host, port, transport, security.
 * Scheme-specific:
 *  * security = tls | reality → sni required;
 *  * security = reality      → publicKey required (shortId optional).
 *
 * A missing mandatory parameter means "configuration unavailable" —
 * never a fabricated URI.
 */
export function validateIngressConfig(
  config: XrayIngressConfig,
): IngressValidationResult {
  if (!config.host) return { valid: false, reason: 'host missing' };
  if (!config.port) return { valid: false, reason: 'port missing' };
  if (!config.transport) return { valid: false, reason: 'transport missing' };
  if (!config.security) return { valid: false, reason: 'security missing' };

  const security = config.security.toLowerCase();
  if (security === 'tls' || security === 'reality') {
    if (!config.sni) return { valid: false, reason: 'sni required for this security scheme' };
  }
  if (security === 'reality') {
    if (!config.publicKey) {
      return { valid: false, reason: 'publicKey required for REALITY (set it on the node)' };
    }
  }
  return { valid: true };
}
