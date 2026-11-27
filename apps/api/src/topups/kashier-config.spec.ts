import { validateKashierEnvironment } from './kashier-config';

describe('validateKashierEnvironment', () => {
  it('allows the Live API host in production over HTTPS', () => {
    expect(() => validateKashierEnvironment({
      NODE_ENV: 'production',
      KASHIER_BASE_URL: 'https://api.kashier.io',
    })).not.toThrow();
  });

  it('rejects the Test API host in production unless explicitly allowed', () => {
    for (const host of ['https://test-api.kashier.io', 'https://test-fep.kashier.io']) {
      expect(() => validateKashierEnvironment({
        NODE_ENV: 'production',
        KASHIER_BASE_URL: host,
      })).toThrow(/Test Kashier host.*not allowed/i);
    }

    expect(() => validateKashierEnvironment({
      NODE_ENV: 'production',
      KASHIER_BASE_URL: 'https://test-api.kashier.io',
      KASHIER_ALLOW_TEST_IN_PRODUCTION: 'true',
    })).not.toThrow();
  });

  it('rejects HTTP hosts in production', () => {
    expect(() => validateKashierEnvironment({
      NODE_ENV: 'production',
      KASHIER_BASE_URL: 'http://api.kashier.io',
    })).toThrow(/HTTPS/i);
  });

  it('keeps local environments restricted to the Test API host', () => {
    expect(() => validateKashierEnvironment({
      NODE_ENV: 'development',
      KASHIER_BASE_URL: 'https://test-api.kashier.io',
    })).not.toThrow();

    expect(() => validateKashierEnvironment({
      NODE_ENV: 'development',
      KASHIER_BASE_URL: 'https://api.kashier.io',
    })).toThrow(/non-Test/i);
  });
});
