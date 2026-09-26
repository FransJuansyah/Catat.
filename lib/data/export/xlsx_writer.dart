import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Satu sheet Excel sederhana.
class XlsxSheet {
  const XlsxSheet(
    this.name, {
    required this.rows,
    this.widths = const [],
    this.boldRows = const {},
  });

  /// Maks 31 huruf (batas Excel).
  final String name;

  /// Isi sel: String, int/double (angka), DateTime (tanggal-jam), null (kosong).
  final List<List<Object?>> rows;

  /// Lebar kolom (satuan karakter), urut dari kolom A.
  final List<double> widths;

  /// Index baris (0-based) yang ditebalkan, mis. judul tabel.
  final Set<int> boldRows;
}

// Gaya sel di styles.xml.
const _plain = 0;
const _bold = 1;
const _money = 2;
const _date = 3;
const _moneyBold = 4;

/// Buat file .xlsx (Office Open XML) tanpa library Excel: cukup zip berisi
/// beberapa file XML. Teks memakai inline string supaya tidak butuh
/// sharedStrings.
Uint8List buildXlsx(List<XlsxSheet> sheets) {
  final archive = Archive();
  void add(String path, String xml) =>
      // `<?xml` harus karakter pertama file.
      archive.addFile(ArchiveFile.bytes(path, utf8.encode(xml.trim())));

  add('[Content_Types].xml', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
${[for (var i = 1; i <= sheets.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join('\n')}
</Types>''');

  add('_rels/.rels', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''');

  add('xl/workbook.xml', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
${[for (final (i, s) in sheets.indexed) '<sheet name="${_esc(_sheetName(s.name))}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join('\n')}
</sheets>
</workbook>''');

  add('xl/_rels/workbook.xml.rels', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${[for (var i = 1; i <= sheets.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join('\n')}
<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''');

  add('xl/styles.xml', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="dd/mm/yyyy hh:mm"/></numFmts>
<fonts count="2">
<font><sz val="11"/><name val="Calibri"/></font>
<font><b/><sz val="11"/><name val="Calibri"/></font>
</fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="5">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
<xf numFmtId="3" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>
</cellXfs>
</styleSheet>''');

  for (final (i, sheet) in sheets.indexed) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(sheet));
  }
  return ZipEncoder().encodeBytes(archive);
}

String _sheetXml(XlsxSheet sheet) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n')
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );
  if (sheet.widths.isNotEmpty) {
    b.write('<cols>');
    for (final (i, w) in sheet.widths.indexed) {
      b.write(
        '<col min="${i + 1}" max="${i + 1}" width="$w" customWidth="1"/>',
      );
    }
    b.write('</cols>');
  }
  b.write('<sheetData>');
  for (final (r, row) in sheet.rows.indexed) {
    final bold = sheet.boldRows.contains(r);
    b.write('<row r="${r + 1}">');
    for (final (c, value) in row.indexed) {
      if (value == null) continue;
      final ref = '${columnName(c)}${r + 1}';
      switch (value) {
        case final num n:
          final style = n is int ? (bold ? _moneyBold : _money) : _plain;
          b.write('<c r="$ref" s="$style"><v>$n</v></c>');
        case final DateTime d:
          b.write('<c r="$ref" s="$_date"><v>${excelDate(d)}</v></c>');
        default:
          b.write(
            '<c r="$ref" t="inlineStr" s="${bold ? _bold : _plain}">'
            '<is><t xml:space="preserve">${_esc('$value')}</t></is></c>',
          );
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

/// 0 → A, 25 → Z, 26 → AA.
String columnName(int index) {
  var n = index + 1;
  var name = '';
  while (n > 0) {
    final rem = (n - 1) % 26;
    name = String.fromCharCode(65 + rem) + name;
    n = (n - 1) ~/ 26;
  }
  return name;
}

/// Tanggal Excel = jumlah hari sejak 30 Des 1899 (pecahan = jam).
double excelDate(DateTime d) {
  final utc = DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
  return utc.difference(DateTime.utc(1899, 12, 30)).inSeconds / 86400;
}

String _sheetName(String name) {
  final clean = name.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ');
  return clean.length > 31 ? clean.substring(0, 31) : clean;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    // Karakter kontrol tidak boleh ada di XML.
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
