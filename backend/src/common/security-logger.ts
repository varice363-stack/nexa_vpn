import { Injectable, Logger } from '@nestjs/common';

/**
 * Security event logger for tracking suspicious activities.
 *
 * Logs security-relevant events to a separate file for monitoring and alerting.
 */
@Injectable()
export class SecurityLogger {
  private readonly logger = new Logger('SECURITY');

  /**
   * Log a security warning event.
   */
  warn(message: string, metadata?: Record<string, unknown>) {
    this.logger.warn(message, metadata ? JSON.stringify(metadata) : undefined);
  }

  /**
   * Log a critical security event (immediate attention required).
   */
  critical(message: string, metadata?: Record<string, unknown>) {
    this.logger.error(
      `[CRITICAL] ${message}`,
      metadata ? JSON.stringify(metadata) : undefined,
    );
  }

  /**
   * Log a failed authentication attempt.
   */
  failedAuth(type: string, identifier: string, ip: string) {
    this.warn(`Failed ${type} attempt`, {
      type,
      identifier,
      ip,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Log a blocked CORS request.
   */
  blockedCors(origin: string, ip: string) {
    this.warn(`Blocked CORS request`, {
      origin,
      ip,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Log rate limit exceeded.
   */
  rateLimitExceeded(endpoint: string, ip: string, attempts: number) {
    this.warn(`Rate limit exceeded`, {
      endpoint,
      ip,
      attempts,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Log suspicious pattern detected.
   */
  suspiciousActivity(pattern: string, details: Record<string, unknown>) {
    this.critical(`Suspicious activity detected: ${pattern}`, {
      ...details,
      timestamp: new Date().toISOString(),
    });
  }
}
