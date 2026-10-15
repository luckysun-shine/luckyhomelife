import test from 'node:test';
import assert from 'node:assert/strict';
import { can } from '../dist/modules/families/permissions.js';

test('管理员可以管理成员', () => {
  assert.equal(can('admin', 'member:manage'), true);
});

test('儿童不能邀请或管理成员', () => {
  assert.equal(can('child', 'member:invite'), false);
  assert.equal(can('child', 'member:manage'), false);
});

test('成人可以邀请但不能管理成员', () => {
  assert.equal(can('adult', 'member:invite'), true);
  assert.equal(can('adult', 'member:manage'), false);
});

test('仅管理员可以查看审计记录', () => {
  for (const role of ['adult', 'elder', 'teen', 'child', 'caregiver']) {
    assert.equal(can(role, 'audit:read'), false);
  }
  assert.equal(can('admin', 'audit:read'), true);
});

test('所有家庭角色均可查看家庭与成员', () => {
  for (const role of ['admin', 'adult', 'elder', 'teen', 'child', 'caregiver']) {
    assert.equal(can(role, 'family:read'), true);
    assert.equal(can(role, 'member:read'), true);
  }
});
