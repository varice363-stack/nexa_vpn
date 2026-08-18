import { VpnServer } from '@prisma/client';

/**
 * Provider-independent Xray ingress configuration contract.
 *
 * Describes everything required to build a client-side VLESS URI from a
 * node. Secrets (privateKey, API tokens) are NEVER part of this contract —
 * they live in the env/config layer of the ingress deployment.
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

/** Maps a persisted VpnServer onto the ingress contract. */
export function toXrayIngressConfig(
  server: Pick<
    VpnServer,
    'ip' | 'port' | 'transport' | 'security' | 'sni' | 'flow' | 'publicKey' | 'shortId'
  >,
): XrayIngressConfig {
  return {
    host: server.ip,
    port: server.port ?? 0,
    transport: server.transport ?? '',
    security: server.security ?? '',
    sni: server.sni,
    flow: server.flow,
    publicKey: server.publicKey,
    shortId: server.shortId,
  };
}

/**
 * Validates an ingress config BEFORE URI generation.
 *
 * Mandatory for any scheme: host, port, transport, security.
 * Scheme-specific:
 *  * security = tls | reality → sni required;
 *  * security = reality    → publicKey required (flow/shortId optional).
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
    if (!config.publicKey) return { valid: false, reason: 'publicKey required for reality' };
  }
  return { valid: true };
}
