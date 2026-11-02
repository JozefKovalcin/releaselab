import { spawn } from 'node:child_process';

async function main() {
  const addr = new URL(process.env.VAULT_ADDR ?? 'http://vault:8200');
  if (!['http:', 'https:'].includes(addr.protocol)) throw new Error('Invalid Vault URL');
  const request = async (path, options = {}) => fetch(new URL(`/v1/${path}`, addr), {
    ...options, signal: AbortSignal.timeout(15000),
  });
  let token;
  let revoke = false;
  const mode = process.env.VAULT_AUTH_MODE ?? 'jwt';
  if (mode === 'jwt') {
    if (!process.env.VAULT_ID_TOKEN) throw new Error('Missing GitLab ID token');
    const login = await request('auth/jwt/login', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ role: process.env.VAULT_AUTH_ROLE ?? 'releaselab-ci', jwt: process.env.VAULT_ID_TOKEN }),
    });
    if (!login.ok) throw new Error('Vault JWT authentication failed');
    token = (await login.json()).auth?.client_token;
    revoke = true;
  } else if (mode === 'token') token = process.env.VAULT_TOKEN;
  else throw new Error('VAULT_AUTH_MODE must be jwt or token');
  if (!token) throw new Error('Missing scoped Vault token');
  const headers = { 'X-Vault-Token': token };
  try {
    const secret = await request('secret/data/releaselab/ci', { headers });
    if (!secret.ok) throw new Error('Vault secret read failed');
    const key = (await secret.json()).data?.data?.api_key;
    if (typeof key !== 'string' || key.length < 16) throw new Error('Invalid Vault API key');
    const denied = await request('secret/data/releaselab/forbidden', { headers });
    if (denied.status !== 403) throw new Error('Vault least privilege check failed');
    console.log('Vault: allowed path readable; forbidden path denied (403).');
    const env = { ...process.env, RELEASELAB_API_KEY: key };
    delete env.VAULT_TOKEN;
    delete env.VAULT_ID_TOKEN;
    const exitCode = await new Promise((resolve, reject) => {
      const windows = process.platform === 'win32';
      const child = spawn(windows ? 'cmd.exe' : 'npm', windows ? ['/d', '/s', '/c', 'npm test'] : ['test'], {
        cwd: new URL('../app/', import.meta.url), env, stdio: 'inherit',
      });
      child.once('error', reject);
      child.once('exit', code => resolve(code ?? 1));
    });
    process.exitCode = exitCode;
  } finally {
    if (revoke) {
      const result = await request('auth/token/revoke-self', { method: 'POST', headers });
      if (!result.ok) throw new Error('Vault token revocation failed');
    }
  }
}
main().catch(() => { console.error('Vault test job failed; check connectivity, auth and scoped policy.'); process.exitCode = 1; });
