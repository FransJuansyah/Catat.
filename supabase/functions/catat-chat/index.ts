// catat. — chat AI untuk mencatat uang keluar/masuk (layar 60, 65–67), hitung
// cicilan & tagihan (72–73), dan daftar sambil ngobrol (74–75).
//
// App memanggil fungsi ini (bukan Groq langsung) supaya kunci API tidak ada di
// APK. Jawaban dipaksa mengikuti skema JSON (structured outputs strict).
//
// Mode (body.mode):
// - tanpa mode / v1 : catat | tanya | tolak            (app lama, jangan diubah)
// - v >= 2          : + cicilan (simulasi kredit) | tagihan (cicilan rutin)
// - 'daftar'        : AI menanyakan data daftar satu per satu → profil
//
// Secret: GROQ_API_KEY (wajib), GROQ_MODEL (opsional), CHAT_DAILY_LIMIT (opsional).
// Deploy: npx supabase functions deploy catat-chat --no-verify-jwt
//   (JWT dicek di sini lewat auth.getUser; akun tamu/anonim juga boleh).
import { createClient } from 'npm:@supabase/supabase-js@2';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const MODEL = Deno.env.get('GROQ_MODEL') ?? 'openai/gpt-oss-120b';
const DAILY_LIMIT = Number(Deno.env.get('CHAT_DAILY_LIMIT') ?? '50');
const MAX_TURNS = 16;
const MAX_CHARS = 600;
const MAX_AMOUNT = 100_000_000_000;

type Turn = { role: 'user' | 'assistant'; text: string };
type Pocket = { name: string; type: 'wajib' | 'darurat' | 'keinginan' };
type Raw = Record<string, unknown>;

// ------------------------------------------------------------------ skema

const NOTE = {
  type: 'object',
  additionalProperties: false,
  required: ['kind', 'amount', 'title', 'pocket', 'days_ago'],
  properties: {
    kind: { type: 'string', enum: ['keluar', 'masuk'] },
    amount: { type: 'integer' },
    title: { type: 'string' },
    pocket: { type: ['string', 'null'] },
    days_ago: { type: 'integer' },
  },
};

const BILL = {
  type: 'object',
  additionalProperties: false,
  required: ['name', 'amount', 'due_day', 'remaining', 'pocket'],
  properties: {
    name: { type: 'string' },
    amount: { type: 'integer' },
    due_day: { type: 'integer' },
    remaining: { type: ['integer', 'null'] },
    pocket: { type: ['string', 'null'] },
  },
};

const SCHEMA_V1 = {
  type: 'object',
  additionalProperties: false,
  required: ['action', 'reply', 'notes'],
  properties: {
    action: { type: 'string', enum: ['catat', 'tanya', 'tolak'] },
    reply: { type: 'string' },
    notes: { type: 'array', items: NOTE },
  },
};

const SCHEMA_V2 = {
  type: 'object',
  additionalProperties: false,
  required: ['action', 'reply', 'notes', 'sim', 'bills'],
  properties: {
    action: { type: 'string', enum: ['catat', 'cicilan', 'tagihan', 'tanya', 'tolak'] },
    reply: { type: 'string' },
    notes: { type: 'array', items: NOTE },
    sim: {
      type: 'object',
      additionalProperties: false,
      required: ['item', 'price', 'dp', 'months', 'rate', 'rate_per'],
      properties: {
        item: { type: 'string' },
        price: { type: 'integer' },
        dp: { type: 'integer' },
        months: { type: 'integer' },
        rate: { type: 'number' },
        rate_per: { type: 'string', enum: ['bulan', 'tahun'] },
      },
    },
    bills: { type: 'array', items: BILL },
  },
};

const SCHEMA_DAFTAR = {
  type: 'object',
  additionalProperties: false,
  required: ['action', 'reply', 'chips', 'step', 'profile'],
  properties: {
    action: { type: 'string', enum: ['tanya', 'selesai', 'tolak'] },
    reply: { type: 'string' },
    chips: { type: 'array', items: { type: 'string' } },
    step: { type: 'integer' },
    profile: {
      type: 'object',
      additionalProperties: false,
      required: ['name', 'mode', 'amount', 'frequency', 'payday', 'weekday', 'estimate', 'balance', 'template', 'bills'],
      properties: {
        name: { type: 'string' },
        mode: { type: 'string', enum: ['', 'gaji', 'jajan', 'tidak_tentu'] },
        amount: { type: 'integer' },
        frequency: { type: 'string', enum: ['', 'harian', 'mingguan', 'bulanan'] },
        payday: { type: 'integer' },
        weekday: { type: 'integer' },
        estimate: { type: 'integer' },
        balance: { type: 'integer' },
        template: { type: 'string', enum: ['', 'klasik', 'anak_kos', 'pejuang_nabung', 'pelajar', 'freelancer'] },
        bills: { type: 'array', items: BILL },
      },
    },
  },
};

// ---------------------------------------------------------------- prompt

const NOTE_RULES = `amount dalam rupiah bulat (25rb = 25000, 1,5jt = 1500000, ceban = 10000). title singkat & rapi (maks 40 huruf, huruf depan kapital), contoh "Kopi susu", "Dimas bayar utang". kind "masuk" untuk gaji, bonus, dikasih, transferan, orang lain bayar/balikin utang ke user, jual barang; "keluar" untuk beli, bayar, jajan, user bayar utang ke orang lain, minjemin. pocket = nama kantong dari daftar di atas yang paling cocok untuk uang keluar (jenis wajib = kebutuhan pokok, darurat = kesehatan/mendadak, keinginan = jajan/hiburan); null untuk uang masuk. days_ago = 0 hari ini, 1 kemarin, dst.`;

function catatPrompt(pockets: Pocket[], today: string, v2: boolean): string {
  const list = pockets.map((p) => `- ${p.name} (jenis ${p.type})`).join('\n');
  const extra = v2
    ? `
- action "cicilan": user minta dihitungkan / simulasi kredit atau cicilan barang ("kalo kredit hp 3jt dp 500rb 12 bulan bunga 2%, sebulan berapa?"). Isi sim: item (nama barang singkat, mis. "HP"), price (harga barang), dp (uang muka, 0 kalau tidak ada), months (lama cicilan, bulan), rate (bunga dalam persen, mis. 2 untuk 2%), rate_per ("bulan" atau "tahun", ikut kata user; default "bulan"). Kalau harga atau lama cicilan belum ada → action "tanya". Kalau bunga tidak disebut, tanya sekali; kalau user bilang tanpa bunga / 0% → rate 0. JANGAN menghitung sendiri, aplikasi yang menghitung. reply = satu kalimat pendek, mis. "Ini hitungannya, pakai bunga flat 2% per bulan ya."
- action "tagihan": user minta dicatat/diingatkan tagihan atau cicilan RUTIN yang dibayar tiap bulan ("cicilan motor 850rb tiap tanggal 5 sisa 20x", "kos 1,5jt tiap tgl 1", "ingetin bayar wifi 300rb tgl 20"). Isi bills: name (rapi, mis. "Cicilan motor"), amount (per bulan), due_day (tanggal 1-31), remaining (sisa berapa kali bayar; null kalau rutin terus tanpa akhir seperti kos/wifi/langganan), pocket (nama kantong yang cocok atau null). Kalau tanggal bayar belum jelas → action "tanya". reply = satu kalimat pendek minta cek dulu (BELUM tersimpan), boleh sebut akan diingatkan sehari sebelumnya.
- Bedakan: "bayar cicilan motor 850rb" / "barusan bayar kos" = uang keluar sekarang → action "catat". Yang ada kata "tiap bulan/tiap tanggal/sisa ...x/ingetin" → action "tagihan".
- Untuk action selain "cicilan", isi sim dengan item "" dan angka 0, rate_per "bulan". Untuk action selain "tagihan", bills = [].`
    : '';
  return `Kamu asisten pencatat keuangan di aplikasi catat. untuk anak muda Indonesia. Tugasmu HANYA urusan uang user: mencatat uang keluar/masuk${v2 ? ', menghitung simulasi cicilan, dan mencatat tagihan rutin' : ''}. Hari ini ${today}.

Kantong user:
${list}

Aturan:
- action "catat": semua info lengkap. Isi notes (boleh lebih dari satu). ${NOTE_RULES} reply = satu kalimat pendek minta user cek dulu (catatan BELUM tersimpan, jangan bilang sudah masuk/tercatat).${extra}
- action "tanya": info kurang, misalnya nominal tidak ada, tidak jelas uang masuk atau keluar, atau maksudnya ambigu. reply = SATU pertanyaan pendek & ramah dalam bahasa santai. notes = [].
- action "tolak": di luar urusan uang user (cuaca, curhat, tanya umum, minta saran investasi saham/kripto, dll). reply = satu kalimat sopan bahwa kamu cuma bisa bantu catat uang${v2 ? ', hitung cicilan, dan tagihan' : ' keluar & masuk'}, plus contoh kalimat. notes = [].
- Koreksi: kalau pesan asisten sebelumnya berisi "Kartu sekarang", itu daftar catatan yang sedang dicek user. Pesan user berikutnya adalah koreksi (ubah nominal, nama, kantong, masuk/keluar, hapus, atau tambah catatan). Balas action "catat" dengan notes berisi DAFTAR LENGKAP setelah dikoreksi, termasuk catatan yang tidak diubah.${v2 ? ' Kalau kartunya "(tagihan)", balas action "tagihan" dengan bills berisi daftar lengkap setelah dikoreksi.' : ''}
- Pakai konteks obrolan sebelumnya: kalau tadi kamu bertanya nominal lalu user menjawab "25rb", gabungkan dengan barang yang disebut sebelumnya.
- Jangan mengarang nominal. Bahasa reply: Indonesia santai, tanpa emoji, maksimal 20 kata.`;
}

function daftarPrompt(today: string): string {
  return `Kamu asisten ramah aplikasi catat. (pencatat keuangan anak muda Indonesia). Kamu sedang membantu user BARU daftar dengan ngobrol santai. Hari ini ${today}. Tanyakan SATU hal per pesan, berurutan, dan JANGAN mengulang pertanyaan yang sudah dijawab:

1. Nama panggilan. (step 1) Pesan asisten pertama (sapaan) SUDAH menanyakan nama, jadi jawaban pertama user = nama panggilannya: simpan di profile.name (huruf depan kapital) lalu langsung lanjut ke pertanyaan 2. Hanya tanya ulang kalau jawabannya jelas bukan nama.
2. Uang user biasanya dari mana: gaji bulanan, uang jajan (dari orang tua, harian/mingguan/bulanan), atau nggak tentu (freelance/usaha). chips: ["Gaji bulanan", "Uang jajan", "Nggak tentu"]. (step 2)
3. Nominal & jadwalnya (step 3):
   - gaji: berapa per bulan & tanggal gajian (payday 1-31).
   - jajan: berapa, tiap hari/minggu/bulan (frequency); mingguan → hari apa (weekday 1=Senin..7=Minggu); bulanan → tanggal (payday).
   - nggak tentu: perkiraan sebulan (estimate, boleh 0 kalau user nggak tahu). amount = 0.
4. Ada cicilan atau tagihan rutin? Misal kos, cicilan HP, kartu kredit, langganan. chips: ["Nggak ada"]. Kalau ada, isi bills (name, amount per bulan, due_day, remaining = sisa berapa kali atau null kalau rutin terus, pocket null). Kalau tanggalnya belum disebut, tanyakan. (step 4)
5. Uang user SEKARANG berapa (saldo yang dipegang saat ini, semua rekening & tunai). (step 5)

Setelah semua lengkap → action "selesai", reply = satu kalimat bahwa ini rangkumannya & minta dicek. Setelah "selesai", kalau user minta ubah sesuatu, ubah profile & tetap action "selesai".

profile selalu diisi LENGKAP dengan semua yang sudah diketahui sejauh ini (bawa nilai lama). Yang belum diketahui: string "", angka 0, balance -1, bills []. template: pilih otomatis — gaji → "klasik", jajan → "pelajar", nggak tentu → "freelancer"; kalau user bilang ngekos → "anak_kos"; kalau user bilang mau rajin nabung → "pejuang_nabung"; kalau user minta template tertentu, ikuti.
amount/estimate/balance dalam rupiah bulat (6,5jt = 6500000, 50rb = 50000).
chips: 0-3 pilihan jawaban cepat yang relevan untuk pertanyaanmu (boleh []).
step: nomor pertanyaan yang sedang kamu tanyakan (1-5); saat "selesai" step = 5.
action "tolak" hanya kalau user bertanya hal di luar daftar/keuangan; reply ajak lanjut daftar, profile tetap dibawa.
Bahasa: Indonesia santai, akrab, tanpa emoji, maksimal 25 kata. Panggil user dengan namanya setelah tahu.`;
}

// ---------------------------------------------------------------- helpers

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function cleanTurns(raw: unknown): Turn[] | null {
  if (!Array.isArray(raw) || raw.length === 0) return null;
  const turns = raw.slice(-MAX_TURNS).map((t) => ({
    role: t?.role === 'assistant' ? 'assistant' : 'user',
    text: String(t?.text ?? '').slice(0, MAX_CHARS),
  })) as Turn[];
  return turns[turns.length - 1].role === 'user' ? turns : null;
}

function cleanPockets(raw: unknown): Pocket[] {
  if (!Array.isArray(raw)) return [];
  return raw.slice(0, 6).map((p) => ({
    name: String(p?.name ?? '').slice(0, 20),
    type: ['wajib', 'darurat', 'keinginan'].includes(p?.type) ? p.type : 'wajib',
  }));
}

const int = (v: unknown, min: number, max: number, fallback = 0) => {
  const n = Math.round(Number(v));
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : fallback;
};

function cleanBills(raw: unknown, names: Set<string>) {
  return (Array.isArray(raw) ? raw : [])
    .map((b: Raw) => ({
      name: String(b?.name ?? '').trim().slice(0, 40),
      amount: int(b?.amount, 0, MAX_AMOUNT),
      due_day: int(b?.due_day, 0, 31),
      remaining: b?.remaining == null ? null : int(b.remaining, 1, 360, 1),
      pocket: typeof b?.pocket === 'string' && names.has(b.pocket) ? b.pocket : null,
    }))
    .filter((b) => b.name && b.amount > 0)
    .slice(0, 10);
}

// ------------------------------------------------------------------ handler

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'method' });
  const groqKey = Deno.env.get('GROQ_API_KEY');
  if (!groqKey) return json(503, { error: 'not_configured' });

  // 1. Harus masuk akun (email atau tamu) → batas harian per akun.
  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );
  const { data: auth } = await admin.auth.getUser(token);
  const user = auth?.user;
  if (!user) return json(401, { error: 'login' });

  let body: Raw;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: 'body' });
  }
  const turns = cleanTurns(body.messages);
  if (!turns) return json(400, { error: 'messages' });
  const pockets = cleanPockets(body.pockets);
  const today = /^\d{4}-\d{2}-\d{2}$/.test(String(body.today))
    ? String(body.today)
    : new Date().toISOString().slice(0, 10);
  const daftar = body.mode === 'daftar';
  const v2 = !daftar && Number(body.v ?? 1) >= 2;

  // 2. Batas harian per akun (kuota Groq gratis dipakai bersama semua user).
  //    Tabel chat_usage belum dibuat (migrasi belum jalan) → tetap dilayani.
  const { data: usedRaw, error: usageError } = await admin.rpc(
    'bump_chat_usage',
    { p_user: user.id },
  );
  if (usageError) console.warn('chat_usage belum aktif:', usageError.message);
  const used = usageError ? 0 : (usedRaw as number);
  if (used > DAILY_LIMIT) {
    return json(429, { error: 'limit', limit: DAILY_LIMIT });
  }

  // 3. Tanya AI dengan jawaban berformat ketat.
  const system = daftar ? daftarPrompt(today) : catatPrompt(pockets, today, v2);
  const schema = daftar ? SCHEMA_DAFTAR : v2 ? SCHEMA_V2 : SCHEMA_V1;
  let res: Response;
  try {
    res = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${groqKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0.2,
        max_completion_tokens: 1500,
        // Daftar butuh mengingat isian sebelumnya → nalar sedikit lebih.
        reasoning_effort: daftar ? 'medium' : 'low',
        messages: [
          { role: 'system', content: system },
          ...turns.map((t) => ({ role: t.role, content: t.text })),
        ],
        response_format: {
          type: 'json_schema',
          json_schema: { name: daftar ? 'daftar' : 'catatan', strict: true, schema },
        },
      }),
      signal: AbortSignal.timeout(20000),
    });
  } catch (_) {
    return json(504, { error: 'ai_timeout' });
  }
  if (res.status === 429) return json(503, { error: 'ai_busy' });
  if (!res.ok) {
    console.error('groq', res.status, await res.text());
    return json(502, { error: 'ai' });
  }
  const completion = await res.json();
  let reply: Raw;
  try {
    reply = JSON.parse(completion.choices[0].message.content);
  } catch {
    return json(502, { error: 'ai_format' });
  }
  const remaining = Math.max(0, DAILY_LIMIT - used);
  const text = String(reply.reply ?? '').slice(0, 240);
  const names = new Set(pockets.map((p) => p.name));

  // 4a. Daftar: saring profil.
  if (daftar) {
    const p = (reply.profile ?? {}) as Raw;
    const pick = (v: unknown, ok: string[]) => (ok.includes(String(v)) ? String(v) : '');
    return json(200, {
      action: ['tanya', 'selesai', 'tolak'].includes(String(reply.action)) ? reply.action : 'tanya',
      reply: text,
      chips: (Array.isArray(reply.chips) ? reply.chips : []).map((c) => String(c).slice(0, 24)).slice(0, 3),
      step: int(reply.step, 1, 5, 1),
      profile: {
        name: String(p.name ?? '').trim().slice(0, 30),
        mode: pick(p.mode, ['gaji', 'jajan', 'tidak_tentu']),
        amount: int(p.amount, 0, MAX_AMOUNT),
        frequency: pick(p.frequency, ['harian', 'mingguan', 'bulanan']),
        payday: int(p.payday, 0, 31),
        weekday: int(p.weekday, 0, 7),
        estimate: int(p.estimate, 0, MAX_AMOUNT),
        balance: int(p.balance, -1, MAX_AMOUNT, -1),
        template: pick(p.template, ['klasik', 'anak_kos', 'pejuang_nabung', 'pelajar', 'freelancer']),
        bills: cleanBills(p.bills, new Set()),
      },
      remaining,
    });
  }

  // 4b. Catat: nominal masuk akal, kantong harus ada di daftar.
  const notes = (Array.isArray(reply.notes) ? reply.notes : [])
    .map((n: Raw) => ({
      kind: n.kind === 'masuk' ? 'masuk' : 'keluar',
      amount: Math.round(Number(n.amount)),
      title: String(n.title ?? '').trim().slice(0, 60),
      pocket: typeof n.pocket === 'string' && names.has(n.pocket) ? n.pocket : null,
      days_ago: int(n.days_ago, 0, 60),
    }))
    .filter((n) => n.amount > 0 && n.amount <= MAX_AMOUNT)
    .slice(0, 20);
  const s = (reply.sim ?? {}) as Raw;
  const sim = {
    item: String(s.item ?? '').trim().slice(0, 40),
    price: int(s.price, 0, MAX_AMOUNT),
    dp: int(s.dp, 0, MAX_AMOUNT),
    months: int(s.months, 0, 360),
    rate: Math.min(100, Math.max(0, Number(s.rate) || 0)),
    rate_per: s.rate_per === 'tahun' ? 'tahun' : 'bulan',
  };
  const bills = v2 ? cleanBills(reply.bills, names).filter((b) => b.due_day >= 1) : [];
  const want = String(reply.action);
  const action = want === 'catat' && notes.length > 0
    ? 'catat'
    : v2 && want === 'cicilan' && sim.price > sim.dp && sim.months > 0
    ? 'cicilan'
    : v2 && want === 'tagihan' && bills.length > 0
    ? 'tagihan'
    : want === 'tolak'
    ? 'tolak'
    : 'tanya';
  return json(200, {
    action,
    reply: text,
    notes: action === 'catat' ? notes : [],
    ...(v2 ? { sim: action === 'cicilan' ? sim : null, bills: action === 'tagihan' ? bills : [] } : {}),
    remaining,
  });
});
