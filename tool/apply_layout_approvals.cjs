// Usage: node tool/apply_layout_approvals.cjs path/to/admin-export.json
// Run only for measurements explicitly approved by the administrator.
const fs = require('fs');
const path = require('path');
const input = process.argv[2];
if (!input) throw Error('Informe o arquivo JSON exportado pelo admin.');
const doc = JSON.parse(fs.readFileSync(input, 'utf8').replace(/^\uFEFF/, ''));
if (doc.version !== 1 || doc.coordinateSpace !== 'viewportDelta' || !doc.elements || typeof doc.elements !== 'object') throw Error('Formato de exportação inválido');
function files(dir) { return fs.readdirSync(dir, {withFileTypes:true}).flatMap(d => d.isDirectory()?files(path.join(dir,d.name)):[path.join(dir,d.name)]); }
const source = files('lib/presentation_royal_clean').filter(p=>p.endsWith('.dart')).map(p=>fs.readFileSync(p,'utf8')).join('\n');
const config = 'docs/approved-layouts.json';
const approved = fs.existsSync(config) ? JSON.parse(fs.readFileSync(config,'utf8')) : {};
for(const [id,v] of Object.entries(doc.elements)) {
 const localId = id.slice(id.indexOf('/')+1).split('#')[0];
 if (!/^[A-Za-z0-9_./#-]+$/.test(id) || !source.includes("'"+localId+"'")) throw Error('Identificador não encontrado: '+id);
 if (!v || !['dx','dy','scale'].every(k=>typeof v[k]==='number'&&Number.isFinite(v[k])) || Math.abs(v.dx)>1 || Math.abs(v.dy)>1 || v.scale<.5 || v.scale>2.5) throw Error('Medidas inválidas: '+id);
 approved[id] = {dx:v.dx,dy:v.dy,scale:v.scale};
}
const entries=Object.entries(approved).sort(([a],[b])=>a.localeCompare(b));
const dart='// Approved admin layout defaults. Preserve stable IDs and values.\nconst layoutSourceDefaultsRoyalClean = <String, Map<String, double>>{\n'+entries.map(([id,v])=>`  '${id}': {'dx': ${v.dx}, 'dy': ${v.dy}, 'scale': ${v.scale}},`).join('\n')+'\n};\n';
fs.writeFileSync('lib/core_royal_clean/constants/layout_defaults_royal_clean.dart',dart);
fs.writeFileSync(config,JSON.stringify(Object.fromEntries(entries),null,2)+'\n');
console.log(`Padrões incorporados: ${entries.length}. Execute análise e testes antes de publicar.`);
