import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ReleasesService } from '../src/releases.service';

test('creates a release and returns independent snapshots', () => {
  const service = new ReleasesService();
  const created = service.create('1.2.3', 'tested');
  assert.equal(service.list().length, 2);
  assert.equal(service.list()[1].version, '1.2.3');
  created.version = 'modified';
  const snapshot = service.list();
  snapshot[1].notes = 'modified';
  assert.equal(service.list()[1].version, '1.2.3');
  assert.equal(service.list()[1].notes, 'tested');
  assert.notEqual(new ReleasesService().list().length, service.list().length);
});
