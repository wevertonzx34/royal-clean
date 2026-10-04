const {spawn} = require('node:child_process');
const {createInterface} = require('node:readline');
const path = require('node:path');
const fs = require('node:fs');

// An allowlist prevents unrelated credentials from reaching the CLI or children.
const allowed = new Set([
  'PATH', 'PATHEXT', 'SYSTEMROOT', 'WINDIR', 'COMSPEC', 'TEMP', 'TMP',
  'HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'PROGRAMDATA',
  'JAVA_HOME', 'LANG', 'LC_ALL', 'TZ', 'NODE_EXTRA_CA_CERTS',
]);
function safeEnvironment(environment) {
  const result = {};
  for (const [name, value] of Object.entries(environment)) {
    if (allowed.has(name.toUpperCase())) result[name] = value;
  }
  result.DEBUG = '';
  result.NODE_OPTIONS = '--use-system-ca';
  return result;
}
function redact(line) {
  return line
    .replace(/sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{16,}/g, '[SEGREDO OCULTO]')
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g, '[TOKEN OCULTO]')
    .replace(/\b(Bearer|Basic)\s+[^\s"',}]+/gi, '$1 [SEGREDO OCULTO]')
    .replace(/((?:OPENAI_API_KEY|[A-Z_]*(?:API_KEY|ACCESS_TOKEN|REFRESH_TOKEN|CLIENT_SECRET)|apiKey|accessToken|refreshToken|clientSecret|authorization|password|private_key)["']?\s*[:=]\s*)(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[^\s,;}]+)/gi,
      '$1[SEGREDO OCULTO]');
}
function run(args) {
  if (!args.length || args.some(a => /^(?:--debug(?:=|$)|--token(?:=|$)|functions:secrets:|login:ci$)/i.test(a))) {
    console.error('Comando ausente ou sensível. Use o console para administrar segredos; debug não é permitido.');
    return 1;
  }
  const source = path.resolve(__dirname, '../functions');
  if (fs.readdirSync(source).some(name => /^(?:\.env|\.secret|\.runtimeconfig\.json)/i.test(name))) {
    console.error('Arquivo local de ambiente/segredos em functions. Use Secret Manager; conteúdo não exibido.');
    return 1;
  }
  if (args[0] === 'deploy') {
    try {
      const {scan, trackedSecrets} = require('./check_secrets.cjs');
      const root = path.resolve(__dirname, '..');
      const findings = [...scan(root).findings, ...trackedSecrets(root)];
      if (findings.length) {
        console.error('Deploy bloqueado pela verificação de segredos.');
        console.error(JSON.stringify(findings));
        return 1;
      }
    } catch (_) {
      console.error('Deploy bloqueado: verificação de segredos não concluída.');
      return 1;
    }
  }
  const cli = path.resolve(__dirname, '../security-tests/node_modules/firebase-tools/lib/bin/firebase.js');
  const child = spawn(process.execPath, [cli, ...args], {
    env: safeEnvironment(process.env), stdio: ['ignore', 'pipe', 'pipe'],
  });
  for (const [source, destination] of [[child.stdout, process.stdout], [child.stderr, process.stderr]]) {
    const lines = createInterface({input: source, crlfDelay: Infinity});
    lines.on('line', line => destination.write(redact(line) + '\n'));
  }
  child.on('error', () => { console.error('Falha ao executar Firebase CLI.'); process.exitCode = 1; });
  child.on('close', code => { process.exitCode = code ?? 1; });
  return child;
}
module.exports = {safeEnvironment, redact, run};
if (require.main === module) {
  const result = run(process.argv.slice(2));
  if (typeof result === 'number') process.exitCode = result;
}
