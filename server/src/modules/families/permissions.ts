import type { FamilyRole } from '../../types.js';

export type FamilyAction =
  | 'family:read'
  | 'member:read'
  | 'member:invite'
  | 'member:manage'
  | 'audit:read';

const permissions: Record<FamilyRole, ReadonlySet<FamilyAction>> = {
  admin: new Set(['family:read', 'member:read', 'member:invite', 'member:manage', 'audit:read']),
  adult: new Set(['family:read', 'member:read', 'member:invite']),
  elder: new Set(['family:read', 'member:read']),
  teen: new Set(['family:read', 'member:read']),
  child: new Set(['family:read', 'member:read']),
  caregiver: new Set(['family:read', 'member:read']),
};

export function can(role: FamilyRole, action: FamilyAction): boolean {
  return permissions[role].has(action);
}

