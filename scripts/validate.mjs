import { createRequire } from 'node:module';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { resolve, join } from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const require = createRequire(new URL('../app/package.json', import.meta.url));
const { parseDocument } = require('yaml');
function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const path = join(dir, entry.name);
    return entry.isDirectory() ? walk(path) : /\.ya?ml$/.test(path) ? [path] : [];
  });
}
const paths = [resolve(root, '.gitlab-ci.yml'), ...['.github', 'infra', 'deploy', 'argocd'].flatMap(dir => walk(resolve(root, dir)))];
let ci;
for (const path of paths) {
  const doc = parseDocument(readFileSync(path, 'utf8'), { uniqueKeys: true });
  if (doc.errors.length) throw new Error(`${path}: ${doc.errors[0].message}`);
  const data = doc.toJS();
  if (path.endsWith('.gitlab-ci.yml')) ci = data;
}
const jobs = Object.entries(ci).filter(([, value]) => value && typeof value === 'object' && value.stage);
for (const [name, job] of jobs) {
  if (!ci.stages.includes(job.stage)) throw new Error(`${name}: unknown stage`);
  for (const keyword of ['script', 'before_script', 'after_script']) {
    if (job[keyword] && (!Array.isArray(job[keyword]) || job[keyword].some(command => typeof command !== 'string'))) {
      throw new Error(`${name}.${keyword}: commands must be strings (quote YAML colons)`);
    }
  }
  for (const need of job.needs ?? []) {
    const dependency = ci[typeof need === 'string' ? need : need.job];
    if (!dependency?.stage || ci.stages.indexOf(dependency.stage) >= ci.stages.indexOf(job.stage)) {
      throw new Error(`${name}: missing or non-earlier dependency`);
    }
    if (need.artifacts && !dependency.artifacts) throw new Error(`${name}: requested artifacts are not produced`);
  }
}
console.log(`Validated ${paths.length} YAML files and ${jobs.length} CI jobs. Use GitLab CI Lint for server-side validation.`);
