const fs = require('node:fs');
const p = require('../security-tests/node_modules/parse5');
const file = 'web_institutional/index.html';
const d = p.parse(fs.readFileSync(file, 'utf8'));
const attr = (n, k) => n.attrs?.find(a => a.name === k)?.value;
const nodes = [];
function walk(n) { nodes.push(n); n.childNodes?.forEach(walk); }
walk(d);
function remove(n) { const a = n.parentNode.childNodes; a.splice(a.indexOf(n), 1); }
for (const n of nodes) {
  if (n.tagName === 'header' || attr(n, 'id') === 'footer') remove(n);
  else if (n.tagName === 'a' && (attr(n, 'class') || '').includes('grid-button')) remove(n);
}
const title = nodes.find(n => attr(n, 'id') === 'wHds_w');
if (!title) throw new Error('Institutional title missing');
const grid = title.parentNode.parentNode;
const fragment = p.parseFragment('<div class="royal-institutional-image" style="--grid-row:1/2;--grid-column:2/7;--m-grid-row:1/2;--m-grid-column:1/6"><img src="/institutional-assets/royal-dados.webp" alt="Coroa Royal Clean" width="1563" height="1563"></div>');
for (const n of fragment.childNodes) { n.parentNode = grid; grid.childNodes.unshift(n); }
const body = nodes.find(n => n.tagName === 'body');
const end = p.parseFragment('<div class="royal-institutional-access"><a id="institutional-app-end" href="/app/">Acessar aplicativo Web — teste</a></div>');
for (const n of end.childNodes) { n.parentNode = body; body.childNodes.push(n); }
const head = nodes.find(n => n.tagName === 'head');
const css = p.parseFragment('<style>.royal-institutional-image{grid-row:1/2;grid-column:2/7;display:flex;align-items:center;justify-content:center;z-index:4}.royal-institutional-image img{display:block;width:72px;height:72px;object-fit:contain}.royal-institutional-access{background:#070b14;padding:40px 16px 56px;text-align:center}.royal-institutional-access a{display:inline-block;padding:16px 24px;border-radius:8px;background:#4d82ff;color:#fff;font:600 16px Sora,sans-serif;text-decoration:none}.royal-institutional-access a:hover{background:#3d68cc}.royal-institutional-access a:focus-visible{outline:3px solid #fff;outline-offset:4px}@media(max-width:920px){.royal-institutional-image{grid-column:1/6}.royal-institutional-image img{width:80px;height:80px}} </style>');
for(const n of css.childNodes){n.parentNode=head;head.childNodes.push(n);}
fs.copyFileSync('assets/preview/royal-store/royal-dados.webp','web_institutional/institutional-assets/royal-dados.webp');
fs.writeFileSync(file,p.serialize(d));
