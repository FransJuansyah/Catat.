// Gabungkan hasil OCR HP (tool/struk_korpus/korpus_out) + kunci jawaban jadi
// test/fixtures/struk/korpus.json (di-commit; fotonya tidak).
//   node tool/buat_fixture_struk.js
// Kunci jawaban: CORD = gt_parse.total.total_price; foto web = tool/struk_web.json.
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, 'struk_korpus');
const ocrDir = path.join(root, 'korpus_out');
const web = JSON.parse(fs.readFileSync(path.join(__dirname, 'struk_web.json'), 'utf8'));

const digits = (v) => {
  if (v == null) return null;
  const s = Array.isArray(v) ? v[0] : typeof v === 'object' ? Object.values(v)[0] : v;
  // "60.000" / "19,500" / "60,000.00" → 60000 (sen ",00" di belakang dibuang).
  const d = String(s)
    .replace(/(\d[.,]\d{3})[.,]\d{2}$/, '$1')
    .replace(/^(\D*\d+)[.,]\d{2}$/, '$1') // "365000.00"
    .replace(/\D/g, '');
  return d ? Number(d) : null;
};

const out = [];
for (const f of fs.readdirSync(ocrDir).sort()) {
  const { id, lines } = JSON.parse(fs.readFileSync(path.join(ocrDir, f), 'utf8'));
  let expect = null;
  if (id.startsWith('cord-')) {
    const gt = JSON.parse(fs.readFileSync(path.join(root, 'cord', `${id}.json`), 'utf8'));
    const total = digits(gt.total && gt.total.total_price);
    if (total) expect = { total };
  } else if (web[id]) {
    expect = web[id];
  }
  if (!expect) continue;
  out.push({ id, expect, lines });
}
const target = path.join(__dirname, '..', 'test', 'fixtures', 'struk', 'korpus.json');
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, JSON.stringify(out));
console.log(`${out.length} struk → ${path.relative(process.cwd(), target)}`);
