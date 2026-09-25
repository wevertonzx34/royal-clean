import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validateBlingTokens, exchangeBlingCode} from '../bling.js';

test('Bling rejects incomplete or malformed tokens without exposing their values', () => {
  const valid = {access_token: 'access-example-value', refresh_token: 'refresh-example-value',
    token_type: 'Bearer', expires_in: 3600, scope: 'products'};
  assert.equal(validateBlingTokens(valid).expiresIn, 3600);
  for (const change of [{access_token: ''}, {refresh_token: null}, {expires_in: 0},
    {expires_in: '3600'}, {expires_in: Infinity}, {token_type: 'Basic'}]) {
    assert.throws(() => validateBlingTokens({...valid, ...change}), /autorização válida/);
  }
});

test('Bling exchange uses server-only Basic auth, JWT header, fixed endpoint and no redirects', async () => {
  const original = globalThis.fetch;
  let called = false;
  globalThis.fetch = async (url, options) => {
    called = true;
    assert.equal(url, 'https://api.bling.com.br/Api/v3/oauth/token');
    assert.equal(options.redirect, 'error');
    assert.equal(options.headers['enable-jwt'], '1');
    assert.equal(options.headers.Authorization, `Basic ${Buffer.from('client:secret').toString('base64')}`);
    assert.equal(options.body.get('code'), 'one-time-code');
    assert.equal(options.body.has('client_secret'), false);
    return {ok: true, json: async () => ({access_token: 'access-example-value', refresh_token: 'refresh-example-value', token_type: 'Bearer', expires_in: 3600})};
  };
  try { await exchangeBlingCode('one-time-code', {clientId: 'client', clientSecret: 'secret'}); }
  finally { globalThis.fetch = original; }
  assert.equal(called, true);
});
