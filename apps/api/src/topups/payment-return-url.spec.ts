import {
  PAYMENT_REDIRECT_PATH,
  parseHttpOrigin,
  parseOriginList,
  resolvePaymentReturnUrl,
} from './payment-return-url';

describe('parseHttpOrigin', () => {
  it('keeps only the origin of an http(s) URL', () => {
    expect(parseHttpOrigin('http://localhost:5173')).toBe('http://localhost:5173');
    expect(parseHttpOrigin('https://app.example.com/some/path?x=1#frag')).toBe('https://app.example.com');
    expect(parseHttpOrigin('  https://app.example.com  ')).toBe('https://app.example.com');
  });

  it('rejects non-http schemes and garbage', () => {
    expect(parseHttpOrigin('myapp://wallet/topup-result')).toBeNull();
    expect(parseHttpOrigin('javascript:alert(1)')).toBeNull();
    expect(parseHttpOrigin('not a url')).toBeNull();
    expect(parseHttpOrigin('')).toBeNull();
    expect(parseHttpOrigin(undefined)).toBeNull();
  });
});

describe('parseOriginList', () => {
  it('splits, normalises, dedupes and drops invalid entries', () => {
    expect(parseOriginList('http://a.test, https://b.test/', 'http://a.test,myapp://x')).toEqual([
      'http://a.test',
      'https://b.test',
    ]);
  });

  it('returns an empty list for missing input', () => {
    expect(parseOriginList(undefined, null, '')).toEqual([]);
  });
});

describe('resolvePaymentReturnUrl', () => {
  beforeEach(() => {
    delete process.env.CORS_ORIGINS;
    delete process.env.CLIENT_ORIGIN;
  });

  it('uses the request origin when it is allow-listed', () => {
    expect(
      resolvePaymentReturnUrl({
        origin: 'http://localhost:5173',
        allowList: 'http://localhost:5173',
        clientOrigin: 'https://other.test',
      }),
    ).toBe(`http://localhost:5173${PAYMENT_REDIRECT_PATH}`);
  });

  it('never carries a path or query from the request origin', () => {
    const url = resolvePaymentReturnUrl({
      origin: 'http://localhost:5173/evil?next=//attacker',
      allowList: 'http://localhost:5173',
    });
    expect(url).toBe(`http://localhost:5173${PAYMENT_REDIRECT_PATH}`);
    expect(url).not.toContain('evil');
  });

  it('falls back to CLIENT_ORIGIN for an unknown/missing origin', () => {
    expect(
      resolvePaymentReturnUrl({
        origin: 'https://evil.example',
        allowList: 'http://localhost:5173',
        clientOrigin: 'http://localhost:5174',
      }),
    ).toBe(`http://localhost:5174${PAYMENT_REDIRECT_PATH}`);
    expect(
      resolvePaymentReturnUrl({ allowList: 'http://localhost:5173', clientOrigin: 'http://localhost:5174' }),
    ).toBe(`http://localhost:5174${PAYMENT_REDIRECT_PATH}`);
  });

  it('falls back to the configured redirect origin last', () => {
    expect(
      resolvePaymentReturnUrl({
        allowList: '',
        configuredRedirectUrl: 'https://tunnel.test/payment-redirect',
      }),
    ).toBe(`https://tunnel.test${PAYMENT_REDIRECT_PATH}`);
  });

  it('returns null when no http(s) candidate exists', () => {
    expect(
      resolvePaymentReturnUrl({ allowList: '', configuredRedirectUrl: 'myapp://wallet/topup-result' }),
    ).toBeNull();
    expect(resolvePaymentReturnUrl({ allowList: '' })).toBeNull();
  });

  it('treats the configured app origin as allow-listed implicitly', () => {
    expect(
      resolvePaymentReturnUrl({ origin: 'http://localhost:5174', clientOrigin: 'http://localhost:5174', allowList: '' }),
    ).toBe(`http://localhost:5174${PAYMENT_REDIRECT_PATH}`);
  });
});
