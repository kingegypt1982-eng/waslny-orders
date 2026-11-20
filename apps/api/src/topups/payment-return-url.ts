/**
 * Flutter Web uses the default hash URL strategy, so a refresh at
 * `<origin>/#/payment-redirect` is served by the same index.html.
 */
export const PAYMENT_REDIRECT_PATH = '/#/payment-redirect';

/** Parses an http(s) origin. Anything else (custom schemes, garbage) -> null. */
export function parseHttpOrigin(value: string | undefined | null): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  try {
    const url = new URL(trimmed);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    return url.origin;
  } catch {
    return null;
  }
}

/** Normalises a comma-separated list (Chrome-style CORS list) into origins. */
export function parseOriginList(...values: Array<string | undefined | null>): string[] {
  const origins = new Set<string>();
  for (const value of values) {
    for (const entry of (value ?? '').split(',')) {
      const origin = parseHttpOrigin(entry);
      if (origin) origins.add(origin);
    }
  }
  return [...origins];
}

export interface PaymentReturnInput {
  /** `Origin` header of the request that created the top-up. */
  origin?: string;
  /** Configured app origin, e.g. CLIENT_ORIGIN. */
  clientOrigin?: string;
  /** Configured fallback, e.g. KASHIER_REDIRECT_URL. */
  configuredRedirectUrl?: string;
  /** Comma-separated allow-list; defaults to CORS_ORIGINS. */
  allowList?: string;
}

/**
 * URL the payer's browser returns to after paying: always
 * `<origin>/#/payment-redirect` (hash route, safe on refresh).
 *
 * Resolution order:
 *  1. the request Origin, but only when it is allow-listed (no open redirect);
 *  2. the configured CLIENT_ORIGIN;
 *  3. the origin of the configured KASHIER_REDIRECT_URL.
 *
 * Only `origin` is ever reused, so a crafted `Origin` cannot smuggle a path
 * or query string into the redirect. Returns null when nothing is usable.
 */
export function resolvePaymentReturnUrl(input: PaymentReturnInput): string | null {
  const allowList = parseOriginList(
    input.allowList ?? process.env.CORS_ORIGINS,
    input.clientOrigin ?? process.env.CLIENT_ORIGIN,
  );

  const requestOrigin = parseHttpOrigin(input.origin);
  if (requestOrigin && allowList.includes(requestOrigin)) {
    return `${requestOrigin}${PAYMENT_REDIRECT_PATH}`;
  }

  const clientOrigin = parseHttpOrigin(input.clientOrigin ?? process.env.CLIENT_ORIGIN);
  if (clientOrigin) return `${clientOrigin}${PAYMENT_REDIRECT_PATH}`;

  const configuredOrigin = parseHttpOrigin(input.configuredRedirectUrl);
  if (configuredOrigin) return `${configuredOrigin}${PAYMENT_REDIRECT_PATH}`;

  return null;
}
