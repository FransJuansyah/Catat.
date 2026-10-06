// catat. — chat AI untuk mencatat uang keluar/masuk (layar 60, 65–67).
//
// App memanggil fungsi ini (bukan Groq langsung) supaya kunci API tidak ada di
// APK. AI cuma boleh: mencatat, bertanya balik kalau info kurang, atau menolak
// topik lain. Jawaban dipaksa mengikuti skema JSON (structured outputs strict).
//
// Secret: GROQ_API_KEY (wajib), GROQ_MODEL (opsional), CHAT_DAILY_LIMIT (opsional).
// Deploy: npx supabase functions deploy catat-chat --no-verify-jwt
//   (JWT dicek di sini lewat auth.getUser, supaya kunci publishable baru pun bisa).
import { createClient } from 'npm:@supabase/supabase-js@2';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const MODEL = Deno.env.get('GROQ_MODEL') ?? 'openai/gpt-oss-120b';
const DAILY_LIMIT = Number(Deno.env.get('CHAT_DAILY_LIMIT') ?? '50');
const MAX_TURNS = 12;
const MAX_CHARS = 500;

type Turn = { role: 'user' | 'assistant'; text: string };
type Pocket = { name: string; type: 'wajib' | 'darurat' | 'keinginan' };

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['action', 'reply', 'notes'],
  properties: {
    action: { type: 'string', enum: ['catat', 'tanya', 'tolak'] },
    reply: { type: 'string' },
    notes: {
      type: 'array',
      items: {
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
      },
    },
  },
};

function systemPrompt(pockets: Pocket[], today: string): string {
  const list = pockets.map((p) => `- ${p.name} (jenis ${p.type})`).join('\n');
  return `Kamu asisten pencatat keuangan di aplikasi catat. untuk anak muda Indonesia. Tugasmu HANYA mengubah obrolan jadi catatan uang keluar atau uang masuk. Hari ini ${today}.

Kantong user:
${list}

Aturan:
- action "catat": semua info lengkap. Isi notes (boleh lebih dari satu). amount dalam rupiah bulat (25rb = 25000, 1,5jt = 1500000, ceban = 10000). title singkat & rapi (maks 40 huruf, huruf depan kapital), contoh "Kopi susu", "Dimas bayar utang". kind "masuk" untuk gaji, bonus, dikasih, transferan, orang lain bayar/balikin utang ke user, jual barang; "keluar" untuk beli, bayar, jajan, user bayar utang ke orang lain, minjemin. pocket = nama kantong dari daftar di atas yang paling cocok untuk uang keluar (jenis wajib = kebutuhan pokok, darurat = kesehatan/mendadak, keinginan = jajan/hiburan); null untuk uang masuk. days_ago = 0 hari ini, 1 kemarin, dst. reply = satu kalimat pendek minta user cek dulu (catatan BELUM tersimpan, jangan bilang sudah masuk/tercatat).
- action "tanya": info kurang, misalnya nominal tidak ada, tidak jelas uang masuk atau keluar, atau maksudnya ambigu. reply = SATU pertanyaan pendek & ramah dalam bahasa santai. notes = [].
- action "tolak": di luar urusan catat uang (cuaca, curhat, tanya umum, minta saran investasi, dll). reply = satu kalimat sopan bahwa kamu cuma bisa bantu catat uang keluar & masuk, plus contoh kalimat. notes = [].
- Koreksi: kalau pesan asisten sebelumnya berisi "Kartu sekarang", itu daftar catatan yang sedang dicek user. Pesan user berikutnya adalah koreksi (ubah nominal, nama, kantong, masuk/keluar, hapus, atau tambah catatan). Balas action "catat" dengan notes berisi DAFTAR LENGKAP setelah dikoreksi, termasuk catatan yang tidak diubah.
- Pakai konteks obrolan sebelumnya: kalau tadi kamu bertanya nominal lalu user menjawab "25rb", gabungkan dengan barang yang disebut sebelumnya.
- Jangan mengarang nominal. Bahasa reply: Indonesia santai, tanpa emoji, maksimal 20 kata.`;
}

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

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json(405, { error: 'method' });
  const groqKey = Deno.env.get('GROQ_API_KEY');
  if (!groqKey) return json(503, { error: 'not_configured' });

  // 1. Harus masuk akun (batas harian per akun).
  const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );
  const { data: auth } = await admin.auth.getUser(token);
  const user = auth?.user;
  if (!user) return json(401, { error: 'login' });

  let body: Record<string, unknown>;
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

  // 2. Batas harian per akun (kuota Groq gratis dipakai bersama semua user).
  //    Tabel chat_usage belum dibuat (migrasi belum jalan) → tetap dilayani
  //    tanpa batas, supaya fungsi bisa dipakai sebelum migrasi diterapkan.
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
        max_completion_tokens: 1024,
        reasoning_effort: 'low',
        messages: [
          { role: 'system', content: systemPrompt(pockets, today) },
          ...turns.map((t) => ({ role: t.role, content: t.text })),
        ],
        response_format: {
          type: 'json_schema',
          json_schema: { name: 'catatan', strict: true, schema: SCHEMA },
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
  let reply: { action: string; reply: string; notes: Array<Record<string, unknown>> };
  try {
    reply = JSON.parse(completion.choices[0].message.content);
  } catch {
    return json(502, { error: 'ai_format' });
  }

  // 4. Saring lagi: nominal masuk akal, kantong harus ada di daftar.
  const names = new Set(pockets.map((p) => p.name));
  const notes = (reply.notes ?? [])
    .map((n) => ({
      kind: n.kind === 'masuk' ? 'masuk' : 'keluar',
      amount: Math.round(Number(n.amount)),
      title: String(n.title ?? '').trim().slice(0, 60),
      pocket: typeof n.pocket === 'string' && names.has(n.pocket) ? n.pocket : null,
      days_ago: Math.min(60, Math.max(0, Math.round(Number(n.days_ago) || 0))),
    }))
    .filter((n) => n.amount > 0 && n.amount <= 100_000_000_000)
    .slice(0, 20);
  const action = reply.action === 'catat' && notes.length > 0
    ? 'catat'
    : reply.action === 'tolak'
    ? 'tolak'
    : 'tanya';
  return json(200, {
    action,
    reply: String(reply.reply ?? '').slice(0, 200),
    notes: action === 'catat' ? notes : [],
    remaining: Math.max(0, DAILY_LIMIT - used),
  });
});
