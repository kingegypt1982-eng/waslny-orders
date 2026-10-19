/**
 * Orders domain constants shared by the service, the expiry scheduler, and
 * the local demo seed script.
 */

/**
 * Orders waiting for a captain expire after this window: the server cancels
 * them and tells the client, so a stale order never sits open forever.
 */
export const ORDER_SEARCH_EXPIRY_MINUTES = 15;

/** Fallbacks when PricingSettings has no radius band configured yet. */
export const DEFAULT_MIN_RADIUS_KM = 2;
export const DEFAULT_MAX_RADIUS_KM = 15;
