const fs = require('node:fs');
const path = require('node:path');
const {randomUUID} = require('node:crypto');
const project = path.resolve(__dirname, '..');
const build = path.join(project, 'build');
const destination = path.join(build, 'site');
const staging = path.join(build, `site-staging-${randomUUID()}`);
const institution = path.join(project, 'web_institutional');
const flutter = path.join(build, 'web');
for (const file of ['index.html', 'segmentos.html', 'sobre.html', 'contato.html']) {
  if (!fs.existsSync(path.join(institution, file))) throw new Error(`Institutional page missing: ${file}`);
}
const html = fs.readFileSync(path.join(flutter, 'index.html'), 'utf8');
if (!html.includes('<base href="/app/">')) throw new Error('Build Flutter Web with --base-href /app/.');
fs.mkdirSync(staging);
fs.cpSync(institution, staging, {recursive: true});
fs.cpSync(flutter, path.join(staging, 'app'), {recursive: true});
const metadata = JSON.parse(fs.readFileSync(path.join(flutter, 'royal-web-release.json'), 'utf8'));
metadata.siteLayout = 'institutional-root-flutter-app';
fs.writeFileSync(path.join(staging, 'royal-web-release.json'), JSON.stringify(metadata, null, 2));
// Keep previous generated artifacts for rollback; no source files are removed.
if (fs.existsSync(destination)) {
  const backup = path.join(build, `site-previous-${randomUUID()}`);
  if (path.dirname(destination) !== build || path.dirname(backup) !== build) throw new Error('Invalid generated output path.');
  fs.renameSync(destination, backup);
}
fs.renameSync(staging, destination);
console.log('Hosting artifacts ready: build/site (institutional /, Flutter /app/).');
