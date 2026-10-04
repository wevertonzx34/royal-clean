const {test} = require('node:test');
const assert = require('node:assert/strict');
const {safeEnvironment, redact, run} = require('./firebase_safe.cjs');
const {inspect} = require('./check_secrets.cjs');
const fake = ['sk', 'proj', 'x'.repeat(40)].join('-');
test('CLI receives only operational environment, never inherited credentials/debug', () => {
  const environment = safeEnvironment({PATH:'tools',JAVA_HOME:'java',DEBUG:'*',
    OPENAI_API_KEY:fake,FIREBASE_TOKEN:fake,OTHER_PASSWORD:fake,NODE_OPTIONS:'--inspect'});
  assert.deepEqual(environment,{PATH:'tools',JAVA_HOME:'java',DEBUG:'',NODE_OPTIONS:'--use-system-ca'});
});
test('Output redacts keys, headers and environment assignments', () => {
  for (const line of [fake, `Authorization: Bearer ${fake}`, `OPENAI_API_KEY="${fake}"`,
    `{"refresh_token":"${'t'.repeat(40)}"}`, `CLIENT_SECRET=${'t'.repeat(40)}`]) {
    const result = redact(line);
    assert.equal(result.includes(fake),false);
    assert.equal(result.includes('t'.repeat(40)),false);
    assert.match(result,/OCULTO/);
  }
  assert.equal(redact('83 tests passed'),'83 tests passed');
});
test('Scanner reports only metadata and rejects client integration', () => {
  const findings = inspect(`const key = '${fake}';`, 'lib/example.dart');
  assert.equal(findings.length,1);
  assert.equal(JSON.stringify(findings).includes(fake),false);
  assert.equal(inspect('OPENAI_API_KEY', 'lib/example.dart').length,1);
  assert.equal(inspect('apiKey: "firebase-public-config"', 'lib/firebase_options.dart').length,0);
});
test('Sensitive CLI commands and debug fail before a process is spawned', () => {
  assert.equal(run(['--debug']),1);
  assert.equal(run(['--debug=true']),1);
  assert.equal(run(['--token=fixture']),1);
  assert.equal(run(['functions:secrets:access','OPENAI_API_KEY']),1);
});
test('Binary SDK strings do not count as credentials, but OpenAI keys still do', () => {
  assert.equal(inspect('Basic ' + 'LibrarySymbol'.repeat(4), 'build/sdk.so', true).length,0);
  assert.equal(inspect(fake, 'build/app.so', true).length,1);
  const fixture = ['test', 'access', 'token'].join('-');
  assert.equal(inspect(`access_token: "${fixture}"`, 'functions/test/example.js').length,0);
});
