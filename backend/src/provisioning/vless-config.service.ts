import { Injectable } from '@nestjs/common';

import { AccessKey } from '@prisma/client';
import {
  validateIngressConfig,
  XrayIngressConfig,
} from './xray-ingress.config';

/**
 * VLESS URI generator — provider-independent, pure function of
 * (AccessKey + validated XrayIngressConfig).
 *
 * TASK #012 rules:
 *  * the URI is built ONLY from the ASSIGNED server's ingress config;
 *  * validation runs BEFORE generation — missing mandatory parameters
 *    (host/port/transport/security, plus scheme-specific sni/publicKey)
 *    yield null (configuration unavailable), never a fabricated URI;
 *  * reality parameters (flow/pbk/sid) are appended when present.
 *
 * The URI is never stored in the database and never logged.
 */
@Injectable()
export class VlessConfigService {
  /**
   * Generates a VLESS URI, or null when the ingress config is invalid.
   */
  generateUri(
    accessKey: Pick<AccessKey, 'uuid' | 'name'>,
    ingress: XrayIngressConfig,
  ): string | null {
    const validation = validateIngressConfig(ingress);
    if (!validation.valid) return null;

    const params = [
      `encryption=none`,
      `type=${ingress.transport}`,
      `security=${ingress.security}`,
    ];
    if (ingress.sni) params.push(`sni=${encodeURIComponent(ingress.sni)}`);
    if (ingress.flow) params.push(`flow=${ingress.flow}`);
    if (ingress.publicKey) params.push(`pbk=${encodeURIComponent(ingress.publicKey)}`);
    if (ingress.shortId) params.push(`sid=${encodeURIComponent(ingress.shortId)}`);

    const remark = encodeURIComponent(accessKey.name || 'Nexa VPN');

    return `vless://${accessKey.uuid}@${ingress.host}:${ingress.port}?${params.join('&')}#${remark}`;
  }

  /** QR payload equals the full URI (Flutter renders the QR itself). */
  qrPayload(
    accessKey: Pick<AccessKey, 'uuid' | 'name'>,
    ingress: XrayIngressConfig,
  ): string | null {
    return this.generateUri(accessKey, ingress);
  }
}
