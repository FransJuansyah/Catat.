import 'package:catat/domain/text_note_parser.dart';
import 'package:catat/domain/types.dart';
import 'package:flutter_test/flutter_test.dart';

List<TextNote> read(String text) {
  final r = parseTextNote(text);
  expect(r, isA<TextNotesRead>(), reason: text);
  return (r as TextNotesRead).notes;
}

TextNote one(String text) {
  final notes = read(text);
  expect(notes, hasLength(1), reason: '$text → $notes');
  return notes.single;
}

void main() {
  group('nominal', () {
    final cases = {
      'kopi 25rb': 25000,
      'kopi 25 rb': 25000,
      'kopi 25k': 25000,
      'kopi 25ribu': 25000,
      'kopi 25.000': 25000,
      'kopi 25,000': 25000,
      'kopi 25000': 25000,
      'kopi Rp 25.000': 25000,
      'kopi rp25000': 25000,
      'parkir rp 500': 500,
      'gajian 6,5jt': 6500000,
      'gajian 6.5 juta': 6500000,
      'gajian 6 juta': 6000000,
      'kos 1.250.000': 1250000,
      'token 2,5rb': 2500,
      'kopi ceban': 10000,
      'parkir goceng': 5000,
      'makan dua puluh lima ribu': 25000,
      'kos satu juta lima ratus ribu': 1500000,
      'jajan seratus lima puluh ribu': 150000,
      'hp sejuta': 1000000,
      'jaket setengah juta': 500000,
      'jaket dua setengah juta': 2500000,
      'es teh lima ribu': 5000,
    };
    cases.forEach((text, amount) {
      test(text, () => expect(one(text).amount, amount));
    });

    test('angka kecil tanpa rb = jumlah barang, bukan nominal', () {
      final n = one('beli 2 kopi 50rb');
      expect(n.amount, 50000);
      expect(n.title, '2 kopi');
    });
  });

  group('judul', () {
    test('buang kata pengisi & cara bayar', () {
      expect(one('tadi beli kopi susu 25rb').title, 'Kopi susu');
      expect(one('makan siang 35rb pake gopay').title, 'Makan siang');
      expect(one('aku abis beli bensin 30rb via dana').title, 'Bensin');
      expect(one('parkir kena 5rb').title, 'Parkir');
      expect(one('nasi padang seharga 28.000 cash').title, 'Nasi padang');
    });

    test('nominal duluan', () {
      final notes = read('25rb kopi, 30rb bensin');
      expect(notes.map((n) => n.title), ['Kopi', 'Bensin']);
      expect(notes.map((n) => n.amount), [25000, 30000]);
    });

    test('keterangan di belakang nominal', () {
      expect(one('bayar 1,2jt buat kos').title, 'Bayar kos');
      expect(one('abis 50rb buat makan').title, 'Makan');
      expect(
        one('dapet transferan 200rb dari mama').title,
        'Dapet transferan dari mama',
      );
      expect(one('50rb buat bensin').title, 'Bensin');
    });

    test('kapital nama tetap dari ketikan asli', () {
      expect(one('Dimas bayar utang 150rb').title, 'Dimas bayar utang');
      expect(one('bayar utang ke Rina 100rb').title, 'Bayar utang ke Rina');
    });

    test('tanpa judul', () {
      expect(one('25rb').title, 'Pengeluaran');
    });
  });

  group('banyak catatan sekaligus', () {
    test('contoh di desain (layar 61)', () {
      final notes = read(
        'tadi beli kopi susu 25rb sama bensin 30rb, terus Dimas bayar utang 150rb',
      );
      expect(notes.map((n) => n.title), [
        'Kopi susu',
        'Bensin',
        'Dimas bayar utang',
      ]);
      expect(notes.map((n) => n.amount), [25000, 30000, 150000]);
      expect(notes.map((n) => n.kind), [
        NoteKind.expense,
        NoteKind.expense,
        NoteKind.income,
      ]);
      expect(notes[0].pocketType, PocketType.keinginan);
      expect(notes[1].pocketType, PocketType.wajib);
    });

    test('baris baru & "dan"', () {
      final notes = read('makan 20rb\nojek 15rb dan pulsa 50rb');
      expect(notes.map((n) => n.title), ['Makan', 'Ojek', 'Pulsa']);
    });
  });

  group('uang masuk vs keluar', () {
    final income = [
      'gajian 6,5jt',
      'dapet bonus 500rb',
      'Dimas bayar utang 150rb',
      'Rina balikin duit 50rb',
      'transferan dari mama 300rb',
      'jual sepatu 250rb',
      'dikasih om 100rb',
      'cashback 12rb',
      'ngutang ke Budi 200rb',
      'uang jajan 100rb',
    ];
    final expense = [
      'bayar utang ke Rina 100rb',
      'aku bayar utang 100rb',
      'minjemin Andi 50rb',
      'transfer ke adik 200rb',
      'bayar gaji ART 1,5jt',
      'tiket masuk 50rb',
      'traktir temen 80rb',
      'kopi 25rb',
    ];
    for (final t in income) {
      test('masuk: $t', () => expect(one(t).kind, NoteKind.income));
    }
    for (final t in expense) {
      test('keluar: $t', () => expect(one(t).kind, NoteKind.expense));
    }
  });

  group('tebak kantong', () {
    test('obat → darurat, nonton → keinginan, listrik → wajib', () {
      expect(one('obat batuk 40rb').pocketType, PocketType.darurat);
      expect(one('nonton bioskop 50rb').pocketType, PocketType.keinginan);
      expect(one('token listrik 100rb').pocketType, PocketType.wajib);
    });
  });

  group('hari', () {
    test('kemarin & beberapa hari lalu', () {
      final k = parseTextNote('kemarin makan 20rb') as TextNotesRead;
      expect(k.daysAgo, 1);
      expect(k.notes.single.title, 'Makan');
      final d = parseTextNote('3 hari lalu beli buku 45rb') as TextNotesRead;
      expect(d.daysAgo, 3);
      expect(d.notes.single.amount, 45000);
      expect(d.notes.single.title, 'Buku');
      expect((parseTextNote('kopi 20rb') as TextNotesRead).daysAgo, 0);
    });
  });

  group('tidak paham', () {
    for (final t in [
      'besok hujan nggak ya?',
      'halo',
      'apa kabar',
      'jam 7 ketemu di kampus',
      'gimana cara nabung 1jt',
      'wkwkwk',
      '',
    ]) {
      test(
        '"$t"',
        () => expect(parseTextNote(t), isA<TextNoteNotUnderstood>()),
      );
    }

    test('soal uang tanpa nominal → minta nominal', () {
      expect(parseTextNote('beli kopi'), isA<TextNoteNeedsAmount>());
      expect(parseTextNote('bayar kos'), isA<TextNoteNeedsAmount>());
    });
  });
}
