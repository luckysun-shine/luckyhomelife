export const familyRoles = ['admin', 'adult', 'elder', 'teen', 'child', 'caregiver'] as const;
export type FamilyRole = (typeof familyRoles)[number];

export interface SessionUser {
  userId: string;
  phone: string;
}

declare module 'fastify' {
  interface FastifyRequest {
    sessionUser?: SessionUser;
  }
}

