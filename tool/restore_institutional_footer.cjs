const fs=require('node:fs');
const p=require('../security-tests/node_modules/parse5');
const attr=(n,k)=>n.attrs?.find(a=>a.name===k)?.value;
function find(n,fn){if(fn(n))return n;for(const child of n.childNodes||[]){const match=find(child,fn);if(match)return match;}}
const file='web_institutional/index.html';
const doc=p.parse(fs.readFileSync(file,'utf8'));
let footer;
for(const dir of fs.readdirSync('build').filter(n=>n.startsWith('site-previous-'))){const path=`build/${dir}/index.html`;if(!fs.existsSync(path))continue;const original=p.parse(fs.readFileSync(path,'utf8'));footer=find(original,n=>attr(n,'id')==='footer');if(footer)break;}
if(!footer)throw new Error('Original footer backup unavailable');
if(!find(doc,n=>attr(n,'id')==='footer')){const cta=find(doc,n=>attr(n,'id')==='cta');footer.parentNode=cta.parentNode;cta.parentNode.childNodes.splice(cta.parentNode.childNodes.indexOf(cta)+1,0,footer);}
const head=find(doc,n=>n.tagName==='head');
const spacing=p.parseFragment('<style id="royal-institutional-spacing">#hero{--block-padding:80px 0 32px 0!important;--block-padding-top:80px!important;--m-block-padding:56px 16px 24px!important}@media(min-width:921px){.royal-institutional-image img{width:64px;height:64px}}@media(max-width:920px){.royal-institutional-image img{width:72px;height:72px}}</style>');
if(!find(doc,n=>attr(n,'id')==='royal-institutional-spacing'))for(const n of spacing.childNodes){n.parentNode=head;head.childNodes.push(n);}
fs.writeFileSync(file,p.serialize(doc));
let adjusted=fs.readFileSync(file,'utf8');
adjusted=adjusted.replace('<style id="royal-institutional-spacing">','<style id="royal-institutional-spacing">#hero .block-layout{padding-top:72px!important}@media(max-width:920px){#hero .block-layout{padding-top:48px!important}}');
fs.writeFileSync(file,adjusted);
fs.copyFileSync(file,'build/site/index.html');
console.log('Original footer restored; responsive hero spacing applied.');
