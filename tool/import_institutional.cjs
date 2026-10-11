// Snapshot the owner's published Builder pages into standalone local HTML/CSS.
// Builder JavaScript, telemetry and hydration configuration are not carried over.
const fs = require('node:fs/promises');
const path = require('node:path');
const {createHash} = require('node:crypto');
const parse5 = require('../security-tests/node_modules/parse5');
const project = path.resolve(__dirname, '..');
const output = path.join(project, 'web_institutional');
const original = 'http://royalcleandistribuidora.com.br';
const allowedHosts = new Set(['royalcleandistribuidora.com.br', 'assets.zyrosite.com', 'cdn.zyrosite.com', 'fonts.gstatic.com']);
const assets = new Map();
const records = [];
const contactEmail = 'royalcleandistribuidora@outlook.com';
const contactWhatsApp = 'https://wa.me/5562982606133';
const cssUrls = /url\(\s*(?:"([^"]*)"|'([^']*)'|([^\s)]+))\s*\)/g;
const attrs = node => Object.fromEntries((node.attrs || []).map(a => [a.name, a.value]));
function setAttr(node, name, value) {
  node.attrs ||= [];
  const existing = node.attrs.find(a => a.name === name);
  if (existing) existing.value = value;
  else node.attrs.push({name, value});
}
async function download(url) {
  const address = new URL(url);
  if (!allowedHosts.has(address.hostname)) throw new Error(`Unreviewed asset host: ${address.hostname}`);
  const response = await fetch(url, {signal: AbortSignal.timeout(30000)});
  if (!response.ok) throw new Error(`HTTP ${response.status}: ${address.pathname}`);
  return {bytes: Buffer.from(await response.arrayBuffer()), type: response.headers.get('content-type') || ''};
}
async function localAsset(raw, base) {
  if (!raw || /^(?:data:|#)/i.test(raw) || raw.startsWith('\\#')) return raw;
  const url = new URL(raw, base).href;
  if (assets.has(url)) return assets.get(url);
  const pending = (async () => {
    const {bytes, type} = await download(url);
    let extension = path.extname(new URL(url).pathname).toLowerCase();
    if (type.includes('text/css')) extension = '.css';
    if (type.includes('image/webp')) extension = '.webp';
    if (type.includes('font/woff2')) extension = '.woff2';
    if (!/^\.[a-z0-9]{1,6}$/.test(extension)) extension = '.bin';
    const name = createHash('sha256').update(url).digest('hex').slice(0, 20) + extension;
    let data = bytes;
    if (extension === '.css') {
      let css = bytes.toString('utf8');
      const references = [...css.matchAll(cssUrls)];
      for (const match of references) {
        const local = await localAsset(match[1] ?? match[2] ?? match[3], url);
        css = css.replaceAll(match[0], `url("${local}")`);
      }
      if (/@import\s+['"]/i.test(css)) throw new Error('CSS import needs review before publishing.');
      data = Buffer.from(css);
    }
    await fs.writeFile(path.join(output, 'institutional-assets', name), data);
    records.push({source: url, local: `/institutional-assets/${name}`, bytes: data.length});
    return `/institutional-assets/${name}`;
  })();
  assets.set(url, pending);
  return pending;
}
function appendFragment(node, html) {
  const fragment = parse5.parseFragment(html);
  for (const child of fragment.childNodes) { child.parentNode = node; node.childNodes.push(child); }
}
async function prepare(node, pageUrl) {
  const next = [];
  for (const child of node.childNodes || []) {
    const a = attrs(child);
    if (child.nodeName === '#text' && child.value) {
      child.value = child.value.replaceAll('atendimento@royalclean.com.br', contactEmail);
    }
    if (child.tagName === 'a' && a.href === 'mailto:atendimento@royalclean.com.br') {
      setAttr(child, 'href', `mailto:${contactEmail}`);
    }
    if (child.tagName === 'a' && a.href === 'https://whatsapp.com/') {
      setAttr(child, 'href', contactWhatsApp);
    }
    if (a.class) {
      setAttr(child, 'class', a.class.split(/\s+/).filter(value => value !== 'transition' && !value.startsWith('transition--')).join(' '));
    }
    if (child.tagName === 'script' && a.type !== 'application/ld+json') continue;
    if (child.tagName === 'iframe') continue;
    if (child.tagName === 'form') {
      setAttr(child, 'id', 'institutional-contact-form');
      setAttr(child, 'data-email', contactEmail);
      // This prepares a message in the visitor's own mail client, not a server submission.
    }
    if (['input', 'textarea'].includes(child.tagName) && ['Name', 'Email', 'Phone', 'Message'].includes(a.id)) {
      setAttr(child, 'name', a.id);
      setAttr(child, 'required', '');
      if (a.id === 'Email') setAttr(child, 'type', 'email');
      if (a.id === 'Phone') setAttr(child, 'type', 'tel');
    }
    if (child.tagName === 'button' && a.type === 'submit') {
      setAttr(child, 'disabled', '');
      child.childNodes = parse5.parseFragment('Preparar e-mail').childNodes;
      for (const item of child.childNodes) item.parentNode = child;
    }
    if (child.tagName === 'meta' && a.name === 'generator') continue;
    if (child.tagName === 'link' && ['prefetch', 'preconnect', 'modulepreload', 'preload'].includes(a.rel)) continue;
    if (child.tagName === 'link' && a.rel === 'stylesheet') setAttr(child, 'href', await localAsset(a.href, pageUrl));
    if (child.tagName === 'link' && ['icon', 'apple-touch-icon'].includes(a.rel)) setAttr(child, 'href', '/institutional-assets/royal-favicon.png');
    if (child.tagName === 'img') {
      setAttr(child, 'src', await localAsset(a.src, pageUrl));
      if (!a.alt) setAttr(child, 'alt', 'Royal Clean Distribuidora');
      // Use the localized source, rather than a Builder responsive CDN URL.
      child.attrs = child.attrs.filter(a => a.name !== 'srcset');
    }
    if (a.style?.includes('url(')) {
      let style = a.style;
      for (const m of [...style.matchAll(cssUrls)]) {
        style = style.replaceAll(m[0], `url("${await localAsset(m[1] ?? m[2] ?? m[3], pageUrl)}")`);
      }
      setAttr(child, 'style', style);
    }
    if (child.tagName === 'html') setAttr(child, 'lang', 'pt-BR');
    if (child.tagName === 'script' && a.type === 'application/ld+json') {
      for (const text of child.childNodes || []) {
        if (text.value) text.value = text.value.replace('"inLanguage":"en"', '"inLanguage":"pt-BR"');
      }
    }
    child.attrs = (child.attrs || []).filter(a => !/^on/i.test(a.name));
    await prepare(child, pageUrl);
    if (child.tagName === 'form') {
      appendFragment(child, '<p class="royal-contact-notice">Ao continuar, abriremos uma mensagem no seu aplicativo de e-mail. Revise e envie por ele; esta página não envia a mensagem automaticamente.</p><p id="institutional-contact-status" role="status"></p><noscript>Utilize o link de e-mail desta página para solicitar atendimento.</noscript>');
    }
    if (['astro-island', 'astro-slot', 'astro-static-slot'].includes(child.tagName)) {
      for (const item of child.childNodes || []) { item.parentNode = node; next.push(item); }
    } else { next.push(child); }
  }
  if (node.childNodes) node.childNodes = next;
}
function wireNavigation(root) {
  let navCount = 0;
  function visit(node) {
    const a = attrs(node);
    if (node.tagName === 'ul' && (a.class || '').includes('block-header__nav-links')) {
      appendFragment(node, `<li class="royal-app-menu-item"><a id="institutional-app-${navCount++}" class="royal-app-access" href="/app/">Acessar Royal Clean</a></li>`);
    }
    if (node.tagName === 'button' && (a.class || '').includes('burger')) {
      setAttr(node, 'id', 'institutional-mobile-menu');
      setAttr(node, 'aria-expanded', 'false');
      setAttr(node, 'aria-controls', 'institutional-mobile-navigation');
    }
    if ((a.class || '').includes('block-header-layout-mobile__dropdown')) {
      setAttr(node, 'id', 'institutional-mobile-navigation');
      setAttr(node, 'hidden', '');
    }
    if (node.tagName === 'head') appendFragment(node, '<link rel="stylesheet" href="/institutional-assets/royal-navigation.css"><script src="/institutional-assets/royal-navigation.js" defer></script>');
    for (const c of node.childNodes || []) visit(c);
  }
  visit(root);
  if (navCount !== 2) throw new Error('Desktop/mobile navigation layout changed; review import.');
}
async function main() {
  await fs.mkdir(path.join(output, 'institutional-assets'), {recursive: true});
  for (const page of ['', 'segmentos', 'sobre', 'contato']) {
    const url = `${original}/${page}`;
    const {bytes} = await download(url);
    await fs.writeFile(path.join(project, '.dart_tool', `institutional-${page || 'home'}-original.html`), bytes);
    const root = parse5.parse(bytes.toString('utf8'));
    await prepare(root, url);
    wireNavigation(root);
    await fs.writeFile(path.join(output, `${page || 'index'}.html`), parse5.serialize(root));
  }
  await fs.copyFile(path.join(project, 'web', 'favicon.png'), path.join(output, 'institutional-assets', 'royal-favicon.png'));
  await fs.writeFile(path.join(project, 'docs', 'institutional-import-assets.json'), JSON.stringify({captured: '2026-10-06', pages: ['/', '/segmentos', '/sobre', '/contato'], assets: records}, null, 2));
  console.log(JSON.stringify({pages: 4, localAssets: records.length, output: 'web_institutional'}));
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
