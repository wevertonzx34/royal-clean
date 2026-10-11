// Isolated browser QA; never attaches to the owner's authenticated Chrome.
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const {chromium} = require('../.dart_tool/web-smoke/node_modules/playwright');
const root = path.resolve(__dirname, '../build/site');
const qa = path.resolve(__dirname, '../docs/web-qa');
fs.mkdirSync(qa, {recursive: true});
const types = {'.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.webp': 'image/webp', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.wasm': 'application/wasm'};
const server = http.createServer((req, res) => {
  const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  if (pathname === '/app') { res.writeHead(301, {Location: '/app/'}); return res.end(); }
  let file = path.resolve(root, '.' + pathname);
  if (!file.startsWith(root + path.sep) && file !== root) { res.writeHead(403); return res.end(); }
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  else if (!fs.existsSync(file) && fs.existsSync(file + '.html')) file += '.html';
  else if (!fs.existsSync(file) && pathname.startsWith('/app/')) file = path.join(root, 'app/index.html');
  if (!fs.existsSync(file)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, {'Content-Type': types[path.extname(file)] || 'application/octet-stream'});
  fs.createReadStream(file).pipe(res);
});
async function main() {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = process.argv[2] || `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: true});
  const report = [];
  try {
    for (const [name, width, height] of [['desktop', 1440, 1000], ['tablet', 768, 1024], ['mobile', 375, 812]]) {
      const page = await browser.newPage({viewport: {width, height}});
      const errors = [], external = [], failed = [];
      page.on('pageerror', error => errors.push(error.name));
      page.on('request', request => { if (/^https?:/.test(request.url()) && new URL(request.url()).host !== new URL(base).host) external.push(new URL(request.url()).hostname); });
      page.on('response', response => { if (response.status() >= 400) failed.push({path: new URL(response.url()).pathname, status: response.status()}); });
      await page.goto(base + '/', {waitUntil: 'networkidle'});
      await page.evaluate(() => document.fonts.ready);
      assert.ok((await page.locator('body').innerText()).includes('compromisso com você'));
      assert.equal(await page.locator('#hero h1').first().evaluate(element => getComputedStyle(element.closest('.layout-element')).opacity), '1');
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), `${name}: horizontal overflow`);
      assert.ok(await page.evaluate(() => [...document.images].every(i => i.complete && i.naturalWidth > 0)), `${name}: images unavailable`);
      assert.deepEqual(external, [], `${name}: institution must use only local assets`);
      assert.deepEqual(failed, [], `${name}: failed resources`);
      assert.deepEqual(errors, [], `${name}: script errors`);
      await page.screenshot({path: path.join(qa, `institutional-${name}.png`), fullPage: true});
      if (name !== 'desktop') {
        const toggle = page.locator('#institutional-mobile-menu');
        assert.ok(await toggle.isVisible(), `${name}: mobile menu missing`);
        await toggle.click();
        assert.equal(await toggle.getAttribute('aria-expanded'), 'true');
        assert.ok(await page.locator('#institutional-app-1').isVisible());
        await page.keyboard.press('Escape');
        assert.equal(await toggle.getAttribute('aria-expanded'), 'false');
        await toggle.click();
        await page.locator('#institutional-app-1').click();
      } else {
        assert.ok(await page.locator('#institutional-app-0').isVisible());
        await page.locator('#institutional-app-0').click();
      }
      assert.ok(page.url().startsWith(base + '/app/'));
      await page.waitForSelector('flutter-view', {timeout: 45000});
      await page.waitForTimeout(6000);
      await page.screenshot({path: path.join(qa, `app-${name}.png`), fullPage: true});
      report.push({viewport: name, width, height, institutionLocalAssets: true, menu: 'passed', appSameOrigin: true, flutterView: true});
      await page.close();
    }
    const page = await browser.newPage();
    for (const route of ['/segmentos', '/sobre', '/contato']) {
      const response = await page.goto(base + route, {waitUntil: 'networkidle'});
      assert.equal(response.status(), 200);
      assert.equal(await page.locator('a[href="/app/"]').count(), 2);
      report.push({route, status: 200, appLinks: 2});
    }
    assert.equal(await page.locator('#institutional-contact-form button[type="submit"]').innerText(), 'Preparar e-mail');
    assert.equal(await page.locator('#institutional-contact-form').evaluate(form => form.checkValidity()), false);
    await page.close();
    fs.writeFileSync(path.join(qa, 'browser-report.json'), JSON.stringify({base, report}, null, 2));
    console.log(JSON.stringify({base, checks: report, screenshots: 'docs/web-qa'}));
  } finally { await browser.close(); }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; }).finally(() => server.close());
