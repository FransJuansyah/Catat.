// Unduh foto struk CORD v2 (NAVER Clova, struk asli Indonesia, CC-BY-4.0)
// + kunci jawaban ke tool/struk_korpus/cord/ (tidak di-commit, lihat .gitignore).
//   node tool/unduh_cord.js [split] [jumlah]
const fs = require('fs');
const path = require('path');

const split = process.argv[2] || 'test';
const count = Number(process.argv[3] || 100);
const out = path.join(__dirname, 'struk_korpus', 'cord');
fs.mkdirSync(out, { recursive: true });

const api = (offset, length) =>
  `https://datasets-server.huggingface.co/rows?dataset=naver-clova-ix/cord-v2&config=default&split=${split}&offset=${offset}&length=${length}`;

(async () => {
  // Split train terlalu besar untuk /rows → pakai /first-rows (100 pertama).
  const pages =
    split === 'train'
      ? [`https://datasets-server.huggingface.co/first-rows?dataset=naver-clova-ix/cord-v2&config=default&split=train`]
      : Array.from({ length: Math.ceil(count / 20) }, (_, k) => api(k * 20, Math.min(20, count - k * 20)));
  for (const url of pages) {
    const page = await (await fetch(url)).json();
    for (const { row_idx, row } of page.rows.slice(0, count)) {
      const id = `cord-${split}-${String(row_idx).padStart(3, '0')}`;
      const jpg = path.join(out, `${id}.jpg`);
      if (!fs.existsSync(jpg)) {
        const img = await fetch(row.image.src);
        fs.writeFileSync(jpg, Buffer.from(await img.arrayBuffer()));
      }
      const gt = JSON.parse(row.ground_truth).gt_parse;
      fs.writeFileSync(path.join(out, `${id}.json`), JSON.stringify(gt, null, 1));
      process.stdout.write('.');
    }
  }
  console.log(`\nselesai: ${fs.readdirSync(out).filter((f) => f.endsWith('.jpg')).length} foto di ${out}`);
})();
