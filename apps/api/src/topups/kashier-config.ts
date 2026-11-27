export function validateKashierEnvironment(env: NodeJS.ProcessEnv): void {
  const isProduction = env.NODE_ENV === 'production';
  const baseUrl = env.KASHIER_BASE_URL?.trim();

  if (!baseUrl) {
    throw new Error('KASHIER_BASE_URL is not set. Refusing to boot without a Kashier API host.');
  }

  let parsed: URL;
  try {
    parsed = new URL(baseUrl);
  } catch {
    throw new Error('KASHIER_BASE_URL must be an absolute URL.');
  }

  const isKashierTestHost = parsed.hostname.startsWith('test-')
    && parsed.hostname.endsWith('.kashier.io');

  if (!isProduction) {
    if (parsed.protocol !== 'https:' || !isKashierTestHost) {
      throw new Error('Refusing a non-Test Kashier host outside production.');
    }
    return;
  }

  if (parsed.protocol !== 'https:') {
    throw new Error('KASHIER_BASE_URL must use HTTPS in production.');
  }

  if (isKashierTestHost && env.KASHIER_ALLOW_TEST_IN_PRODUCTION !== 'true') {
    throw new Error('Test Kashier host is not allowed in production. Set KASHIER_ALLOW_TEST_IN_PRODUCTION=true only for an intentional Test deployment.');
  }
}
