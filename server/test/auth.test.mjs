import test from 'node:test';
import assert from 'node:assert/strict';
import { jwtVerify } from 'jose';
import { createAccessToken } from '../dist/auth.js';

test('访问令牌包含用户身份并具有有效期', async () => {
  const secret = 'test-secret-that-is-at-least-32-characters-long';
  const token = await createAccessToken({ userId: 'user-1', phone: '13800000000' }, secret);
  const { payload } = await jwtVerify(token, new TextEncoder().encode(secret));
  assert.equal(payload.sub, 'user-1');
  assert.equal(payload.phone, '13800000000');
  assert.ok(payload.exp > payload.iat);
});

