import test from 'node:test';
import assert from 'node:assert/strict';
import { loadConfig } from '../dist/config.js';

test('生产配置拒绝过短 JWT 密钥', () => {
  assert.throws(() => loadConfig({ DATABASE_URL: 'postgres://test', JWT_SECRET: 'short' }));
});

test('开发登录默认关闭', () => {
  const config = loadConfig({ DATABASE_URL: 'postgres://test', JWT_SECRET: 'a'.repeat(32) });
  assert.equal(config.ALLOW_DEV_LOGIN, false);
  assert.equal(config.PORT, 8080);
});

test('空的可选外部服务配置会被忽略', () => {
  const config = loadConfig({
    DATABASE_URL: 'postgres://test',
    JWT_SECRET: 'a'.repeat(32),
    FIREBASE_PROJECT_ID: '',
    SMS_WEBHOOK_URL: '',
  });
  assert.equal(config.FIREBASE_PROJECT_ID, undefined);
  assert.equal(config.SMS_WEBHOOK_URL, undefined);
});
