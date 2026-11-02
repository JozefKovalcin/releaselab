import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { createHash, timingSafeEqual } from 'node:crypto';

@Injectable()
export class ApiKeyGuard implements CanActivate {
  private readonly expected: Buffer;
  constructor() {
    const key = process.env.RELEASELAB_API_KEY;
    if (!key || key.length < 16) throw new Error('RELEASELAB_API_KEY must contain at least 16 characters');
    this.expected = createHash('sha256').update(key).digest();
  }

  canActivate(context: ExecutionContext): boolean {
    const supplied: unknown = context.switchToHttp().getRequest().headers['x-api-key'];
    if (typeof supplied !== 'string' || !timingSafeEqual(
      this.expected, createHash('sha256').update(supplied).digest(),
    )) throw new UnauthorizedException('Invalid API key');
    return true;
  }
}
