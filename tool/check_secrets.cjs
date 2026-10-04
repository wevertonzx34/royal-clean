const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

function inspect(data, file, binary = false) {
  const findings = [];
  const rules = [
    ['chave OpenAI', /sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}/g],
    ['chave privada', /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s+[A-Za-z0-9+/=\r\n]{64,}\s+-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g],
    ['credencial literal', /(?:OPENAI_API_KEY|access_token|refresh_token|client_secret|password)\s*["']?\s*[:=]\s*["']([^"'\r\n]{16,})["']/gi],
    ['token literal', /(?:Bearer|Basic)\s+[A-Za-z0-9+\/_.=-]{32,}/g],
  ];
  for (const [category, expression] of rules) {
    if (binary && category !== 'chave OpenAI') continue;
    for (const match of data.matchAll(expression)) {
      if (match[1] && /^(?:\[.*\]|<.*>|\$\{.*\})$/.test(match[1])) continue;
      if (match[1] && /(?:^|[/\\])test(?:s)?[/\\]/.test(file) &&
          /^(?:access|refresh|rotated|test|new|old)[-_][a-z-]+$/i.test(match[1])) continue;
      findings.push({file, line: data.slice(0, match.index).split('\n').length, category});
    }
  }
  // OpenAI integration is explicitly prohibited anywhere in the client bundle.
  if (/^(?:lib|assets)[/\\]|^(?:pubspec\.yaml|firebase\.json)$/.test(file)) {
    for (const match of data.matchAll(/OPENAI_API_KEY|api\.openai\.com/g)) {
      findings.push({file, line: data.slice(0, match.index).split('\n').length, category: 'OpenAI no cliente/configuração'});
    }
  }
  return findings;
}
function scan(root) {
  const findings = [];
  let scanned = 0;
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
      if (['.git', 'node_modules', '.gradle'].includes(entry.name) || entry.isSymbolicLink()) continue;
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) { walk(absolute); continue; }
      if (!entry.isFile()) continue;
      const bytes = fs.readFileSync(absolute);
      const file = path.relative(root, absolute);
      scanned++;
      // Search binary artifacts for full key patterns too; don't print content.
      const utf16 = bytes[0] === 0xff && bytes[1] === 0xfe;
      const binary = !utf16 && bytes.includes(0);
      const data = bytes.toString(utf16 ? 'utf16le' : binary ? 'latin1' : 'utf8');
      findings.push(...inspect(data, file, binary));
    }
  }
  walk(root);
  return {scanned, findings};
}
function trackedSecrets(root) {
  const files = execFileSync('git', ['ls-files', '-z'], {cwd: root, encoding: 'utf8'}).split('\0').filter(Boolean);
  return files.filter(file => /(?:^|\/)(?:\.env(?:\..*)?|\.secret(?:\..*)?|\.runtimeconfig\.json|key\.properties)$|\.(?:jks|keystore|p12|pfx|key)$|(?:service[-_]?account|credentials|firebase-adminsdk).*\.json$/i.test(file))
    .filter(file => !/\.example$/.test(file))
    .map(file => ({file, line: 1, category: 'arquivo sensível rastreado no Git'}));
}
module.exports = {inspect, scan, trackedSecrets};
if (require.main === module) {
  try {
    const root = path.resolve(__dirname, '..');
    const result = scan(root);
    result.findings.push(...trackedSecrets(root));
    console.log(JSON.stringify(result)); // Only locations/categories, never values.
    process.exitCode = result.findings.length ? 1 : 0;
  } catch (_) {
    console.error('Varredura não concluída. Nenhum conteúdo de arquivo foi exibido.');
    process.exitCode = 1;
  }
}
