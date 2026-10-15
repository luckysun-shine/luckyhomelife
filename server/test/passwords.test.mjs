import test from 'node:test';
import assert from 'node:assert/strict';
import { hashPassword, verifyPassword } from '../dist/passwords.js';

test('密码哈希可以校验正确密码并拒绝错误密码', () => {
  const stored = hashPassword('family-home-2026');
  assert.equal(verifyPassword('family-home-2026', stored), true);
  assert.equal(verifyPassword('wrong-password', stored), false);
  assert.equal(verifyPassword('family-home-2026', 'not-a-hash'), false);
});
