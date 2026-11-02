import { Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';

export interface Release { id: string; version: string; notes: string; createdAt: string }

@Injectable()
export class ReleasesService {
  private readonly releases: Release[] = [{
    id: 'demo', version: '0.1.0', notes: 'Welcome to ReleaseLab',
    createdAt: '2026-01-01T00:00:00.000Z',
  }];

  list(): Release[] { return this.releases.map(release => ({ ...release })); }

  create(version: string, notes = ''): Release {
    const release = { id: randomUUID(), version, notes, createdAt: new Date().toISOString() };
    this.releases.push(release);
    return { ...release };
  }
}
