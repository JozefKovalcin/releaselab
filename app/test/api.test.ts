import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { fork, ChildProcess } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { resolve } from 'node:path';

let child: ChildProcess;
let base: string;
const key = process.env.RELEASELAB_API_KEY ?? randomBytes(32).toString('hex');

before(async () => {
  if (process.env.CI && !process.env.RELEASELAB_API_KEY) throw new Error('CI requires an injected API key');
  child = fork(resolve('dist/main.js'), [], {
    env: { ...process.env, PORT: '0', RELEASELAB_API_KEY: key, APP_VERSION: '1.2.3', COMMIT_SHA: 'a'.repeat(40) },
    stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
  });
  await new Promise<void>((done, reject) => {
    const timeout = setTimeout(() => reject(new Error('API startup timed out')), 15000);
    child.once('error', error => { clearTimeout(timeout); reject(error); });
    child.once('exit', () => { clearTimeout(timeout); reject(new Error('API exited before readiness')); });
    child.once('message', (message: { port: number }) => {
      clearTimeout(timeout); base = `http://127.0.0.1:${message.port}`; done();
    });
  });
});
after(async () => {
  if (child && child.exitCode === null) {
    await new Promise<void>(done => { child.once('exit', () => done()); child.kill(); });
  }
});

test('health and exact build metadata', async () => {
  assert.deepEqual(await (await fetch(`${base}/health`)).json(), { status: 'ok' });
  assert.deepEqual(await (await fetch(`${base}/version`)).json(), { version: '1.2.3', commitSha: 'a'.repeat(40) });
});
test('API key authorizes writes; missing and wrong keys cannot modify data', async () => {
  const post = (apiKey?: string, body = { version: '2.0.0', notes: 'integration' }) => fetch(`${base}/releases`, {
    method: 'POST', headers: { 'content-type': 'application/json', ...(apiKey ? { 'x-api-key': apiKey } : {}) },
    body: JSON.stringify(body),
  });
  for (const invalid of [undefined, 'incorrect-api-key']) {
    const response = await post(invalid);
    assert.equal(response.status, 401);
    assert.equal((await (await fetch(`${base}/releases`)).json() as unknown[]).length, 1);
  }
  const response = await post(key);
  assert.equal(response.status, 201);
  const release = await response.json() as { version: string; id: string };
  assert.equal(release.version, '2.0.0');
  assert.ok(release.id);
  assert.equal((await (await fetch(`${base}/releases`)).json() as unknown[]).length, 2);
  assert.equal((await post(key, { version: 'invalid', notes: '' })).status, 400);
  const extra = await fetch(`${base}/releases`, {
    method: 'POST', headers: { 'content-type': 'application/json', 'x-api-key': key },
    body: JSON.stringify({ version: '2.0.1', admin: true }),
  });
  assert.equal(extra.status, 400);
});
