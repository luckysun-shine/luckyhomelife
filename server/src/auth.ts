import type { FastifyReply, FastifyRequest } from 'fastify';
import { SignJWT, jwtVerify } from 'jose';
import type { SessionUser } from './types.js';
import { unauthorized } from './errors.js';

const encoder = new TextEncoder();

export async function createAccessToken(user: SessionUser, secret: string): Promise<string> {
  return new SignJWT({ phone: user.phone })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(user.userId)
    .setIssuedAt()
    .setExpirationTime('30d')
    .sign(encoder.encode(secret));
}

export function authenticate(secret: string) {
  return async (request: FastifyRequest, _reply: FastifyReply) => {
    const authorization = request.headers.authorization;
    if (!authorization?.startsWith('Bearer ')) throw unauthorized();
    try {
      const token = authorization.slice('Bearer '.length);
      const { payload } = await jwtVerify(token, encoder.encode(secret), { algorithms: ['HS256'] });
      if (!payload.sub || typeof payload.phone !== 'string') throw unauthorized();
      request.sessionUser = { userId: payload.sub, phone: payload.phone };
    } catch {
      throw unauthorized('登录状态已失效，请重新登录');
    }
  };
}

