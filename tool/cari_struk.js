// Cari foto struk lewat DuckDuckGo Images → tool/struk_korpus/web/<kategori>-NN.jpg
// Hanya untuk uji akurasi scan di laptop/HP; foto TIDAK di-commit (hak cipta
// milik pengunggahnya). Yang di-commit cuma hasil OCR + kunci jawaban.
//   node tool/cari_struk.js "struk indomaret" indomaret 6
const fs = require('fs');
const path = require('path');

const [query, slug, max = '6'] = process.argv.slice(2);
const out = path.join(__dirname, 'struk_korpus', 'web');
fs.mkdirSync(out, { recursive: true });
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36';

(async () => {
  const home = await (await fetch(`https://duckduckgo.com/?q=${encodeURIComponent(query)}&iax=images&ia=images`, { headers: { 'User-Agent': UA } })).text();
  const vqd = (home.match(/vqd=["']?([\d-]+)/) || [])[1];
  if (!vqd) throw new Error('vqd tidak ketemu');
  const res = await fetch(`https://duckduckgo.com/i.js?l=id-id&o=json&q=${encodeURIComponent(query)}&vqd=${vqd}&f=,,,,,&p=1`, {
    headers: { 'User-Agent': UA, Referer: 'https://duckduckgo.com/' },
  });
  const { results } = await res.json();
  let saved = 0;
  for (const r of results) {
    if (saved >= Number(max)) break;
    // Struk itu tegak & cukup besar untuk dibaca.
    if (r.height < 600 || r.height < r.width * 0.9) continue;
    try {
      const img = await fetch(r.image, { headers: { 'User-Agent': UA }, signal: AbortSignal.timeout(15000) });
      const type = img.headers.get('content-type') || '';
      if (!img.ok || !/jpe?g|png|webp/.test(type)) continue;
      const buf = Buffer.from(await img.arrayBuffer());
      if (buf.length < 30000) continue;
      const ext = type.includes('png') ? 'png' : type.includes('webp') ? 'webp' : 'jpg';
      const name = `${slug}-${String(++saved).padStart(2, '0')}.${ext}`;
      fs.writeFileSync(path.join(out, name), buf);
      fs.appendFileSync(path.join(out, 'sumber.tsv'), `${name}\t${r.image}\t${r.url}\n`);
    } catch (_) {}
  }
  console.log(`${slug}: ${saved} foto (${results.length} hasil)`);
})().catch((e) => console.log(`${slug}: gagal ${e.message}`));
