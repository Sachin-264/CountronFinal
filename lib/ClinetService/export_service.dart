import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';
import 'package:archive/archive.dart'; // REQUIRED FOR DOCX

import '../ClientScreen/ViewData/channel_data_model.dart';

class ExportService {
  static const String _imageBaseUrl = "https://storage.googleapis.com/upload-images-34/images/LMS/";

  // ===========================================================================
  // DATA RESAMPLING LOGIC
  // ===========================================================================
  List<ChannelDataPoint> resampleData(List<ChannelDataPoint> rawData, int intervalMinutes) {
    if (intervalMinutes <= 0) return rawData;
    Map<int, List<ChannelDataPoint>> groups = {};
    for (var point in rawData) {
      int timestamp = point.dateTime.millisecondsSinceEpoch;
      int intervalMs = intervalMinutes * 60 * 1000;
      int roundedTimestamp = (timestamp ~/ intervalMs) * intervalMs;
      if (!groups.containsKey(roundedTimestamp)) groups[roundedTimestamp] = [];
      groups[roundedTimestamp]!.add(point);
    }
    List<ChannelDataPoint> resampled = [];
    groups.forEach((timestamp, points) {
      Map<String, double> averagedValues = {};
      Set<String> keys = points.first.values.keys.toSet();
      for (String key in keys) {
        double sum = 0;
        int count = 0;
        for (var p in points) {
          if (p.values.containsKey(key)) {
            sum += (p.values[key] as num).toDouble();
            count++;
          }
        }
        averagedValues[key] = count > 0 ? double.parse((sum / count).toStringAsFixed(2)) : 0.0;
      }
      resampled.add(ChannelDataPoint(DateTime.fromMillisecondsSinceEpoch(timestamp), averagedValues));
    });
    resampled.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return resampled;
  }

  // ===========================================================================
  // PDF GENERATION
  // ===========================================================================
  Future<void> generateAndSavePdf({
    required List<ChannelDataPoint> data,
    required List<dynamic> channels,
    required Map<String, dynamic> branding,
    required List<String> headerLines,
    required List<String> footerLines,
    required String fileName,
    required String reportDuration,
    required String dataGranularity,
    Uint8List? graphImage,
    required String orientation,
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.05);
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);

      final pdf = pw.Document(theme: pw.ThemeData.withFont(base: ttf, bold: ttf));
      final pageOrientation = orientation == 'Landscape' ? pw.PageOrientation.landscape : pw.PageOrientation.portrait;

      onProgress?.call(0.15);
      pw.MemoryImage? logoImage;
      if (branding['logoPath'] != null && branding['logoPath'].toString().isNotEmpty) {
        try {
          final response = await http.get(Uri.parse("$_imageBaseUrl${branding['logoPath']}"));
          if (response.statusCode == 200) logoImage = pw.MemoryImage(response.bodyBytes);
        } catch (e) {
          debugPrint("Error loading logo: $e");
        }
      }

      pw.MemoryImage? graphMemImage;
      if (graphImage != null) graphMemImage = pw.MemoryImage(graphImage);

      const int rowsPerTable = 100;
      List<List<ChannelDataPoint>> chunks = [];
      for (var i = 0; i < data.length; i += rowsPerTable) {
        chunks.add(data.sublist(i, i + rowsPerTable > data.length ? data.length : i + rowsPerTable));
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          orientation: pageOrientation,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildPdfHeader(context, branding, headerLines, logoImage, reportDuration, dataGranularity),
          footer: (context) => _buildPdfFooter(context, footerLines),
          build: (context) {
            List<pw.Widget> widgets = [];

            if (graphMemImage != null) {
              widgets.add(pw.Text("Trend Analysis Graph", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)));
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(pw.Center(child: pw.Image(graphMemImage, width: pageOrientation == pw.PageOrientation.landscape ? 700 : 450)));
              widgets.add(pw.SizedBox(height: 20));
            }

            for (int i = 0; i < chunks.length; i++) {
              widgets.add(_buildPdfTable(chunks[i], channels, isFirstTable: i == 0));
              widgets.add(pw.SizedBox(height: 10));
            }
            return widgets;
          },
        ),
      );

      onProgress?.call(0.85);
      final bytes = await pdf.save();
      await _saveFile(bytes, fileName, "pdf", MimeType.pdf);
      onProgress?.call(1.0);
    } catch (e) {
      debugPrint("PDF Generation Error: $e");
      rethrow;
    }
  }

  pw.Widget _buildPdfHeader(pw.Context context, Map<String, dynamic> branding, List<String> customLines, pw.MemoryImage? logo, String duration, String granularity) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logo != null) pw.Container(width: 60, height: 60, child: pw.Image(logo)),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(branding['name']?.toString() ?? "Company Name", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(branding['address']?.toString() ?? "Address", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            )
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(duration, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
          pw.Text(granularity, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
        ]),
        pw.SizedBox(height: 5),
        ...customLines.map((line) => pw.Text(line, style: const pw.TextStyle(fontSize: 10))),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context, List<String> customLines) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        ...customLines.map((line) => pw.Text(line, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))),
        pw.SizedBox(height: 4),
        pw.Text("Page ${context.pageNumber} of ${context.pagesCount}", style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  pw.Widget _buildPdfTable(List<ChannelDataPoint> data, List<dynamic> channels, {bool isFirstTable = true}) {
    final headers = ['Date Time', ...channels.map((e) => e['ChannelName']?.toString() ?? 'Unknown')];
    final List<String> unitRow = ['YYYY-MM-DD HH:mm'];
    for (var c in channels) {
      unitRow.add(c['Unit']?.toString() ?? '-');
    }

    final dataRows = data.map((point) {
      List<String> row = [DateFormat('yyyy-MM-dd HH:mm').format(point.dateTime)];
      for (var c in channels) {
        String id = c['ChannelRecNo'].toString();
        var val = point.values[id];
        row.add(val != null ? (val as num).toStringAsFixed(2) : "0.00");
      }
      return row;
    }).toList();

    if (isFirstTable) {
      dataRows.insert(0, unitRow);
    }

    return pw.Table.fromTextArray(
      headers: isFirstTable ? headers : null,
      data: dataRows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  // ===========================================================================
  // EXCEL GENERATION
  // ===========================================================================
  Future<void> generateAndSaveExcel({
    required List<ChannelDataPoint> data,
    required List<dynamic> channels,
    required Map<String, dynamic> branding,
    required List<String> headerLines,
    required String fileName,
    required String reportDuration,
    required String dataGranularity,
    Uint8List? graphImage,
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = "Report";

    int currentRow = 1;

    if (branding['logoPath'] != null && branding['logoPath'].toString().isNotEmpty) {
      try {
        final response = await http.get(Uri.parse("$_imageBaseUrl${branding['logoPath']}"));
        if (response.statusCode == 200) {
          final xlsio.Picture pic = sheet.pictures.addStream(1, 1, response.bodyBytes);
          pic.width = 80;
          pic.height = 40;
        }
      } catch (e) {
        debugPrint("Error loading logo for Excel: $e");
      }
    }
    currentRow = 3;

    sheet.getRangeByIndex(currentRow, 1).setText(branding['name']?.toString() ?? 'Company Name');
    sheet.getRangeByIndex(currentRow, 1).cellStyle.fontSize = 16;
    sheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
    currentRow++;

    sheet.getRangeByIndex(currentRow, 1).setText(branding['address']?.toString() ?? 'Address');
    sheet.getRangeByIndex(currentRow, 1).cellStyle.fontSize = 10;
    currentRow += 2;

    sheet.getRangeByIndex(currentRow, 1).setText(reportDuration);
    sheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
    currentRow++;
    sheet.getRangeByIndex(currentRow, 1).setText(dataGranularity);
    sheet.getRangeByIndex(currentRow, 1).cellStyle.bold = true;
    currentRow += 2;

    for (String line in headerLines) {
      if (line.isNotEmpty) {
        sheet.getRangeByIndex(currentRow, 1).setText(line);
        currentRow++;
      }
    }
    currentRow++;

    if (graphImage != null) {
      final xlsio.Picture graphPic = sheet.pictures.addStream(currentRow, 1, graphImage);
      graphPic.width = 600;
      graphPic.height = 300;
      currentRow += 16;
    }

    final xlsio.Style headerStyle = workbook.styles.add("HeaderStyle");
    headerStyle.bold = true;
    headerStyle.backColor = "#4472C4";
    headerStyle.fontColor = "#FFFFFF";
    headerStyle.hAlign = xlsio.HAlignType.center;

    sheet.getRangeByIndex(currentRow, 1).setText("Date Time");
    sheet.getRangeByIndex(currentRow, 1).cellStyle = headerStyle;
    for(int c=0; c<channels.length; c++) {
      sheet.getRangeByIndex(currentRow, c+2).setText(channels[c]['ChannelName']?.toString() ?? 'CH');
      sheet.getRangeByIndex(currentRow, c+2).cellStyle = headerStyle;
    }
    currentRow++;

    final xlsio.Style unitStyle = workbook.styles.add("UnitStyle");
    unitStyle.backColor = "#D9E1F2";
    unitStyle.hAlign = xlsio.HAlignType.center;

    sheet.getRangeByIndex(currentRow, 1).setText("YYYY-MM-DD HH:mm");
    sheet.getRangeByIndex(currentRow, 1).cellStyle = unitStyle;
    for(int c=0; c<channels.length; c++) {
      sheet.getRangeByIndex(currentRow, c+2).setText(channels[c]['Unit']?.toString() ?? '-');
      sheet.getRangeByIndex(currentRow, c+2).cellStyle = unitStyle;
    }
    currentRow++;

    for(int i=0; i<data.length; i++) {
      int rowIdx = currentRow + i;
      sheet.getRangeByIndex(rowIdx, 1).setText(DateFormat('yyyy-MM-dd HH:mm:ss').format(data[i].dateTime));
      for(int c=0; c<channels.length; c++) {
        String id = channels[c]['ChannelRecNo'].toString();
        var val = data[i].values[id];
        sheet.getRangeByIndex(rowIdx, c + 2).setNumber(val != null ? (val as num).toDouble() : 0.0);
      }
      if (i % 500 == 0) await Future.delayed(Duration.zero);
    }

    sheet.autoFitColumn(1);
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    await _saveFile(Uint8List.fromList(bytes), fileName, "xlsx", MimeType.microsoftExcel);
  }

  // ===========================================================================
  // CSV GENERATION
  // ===========================================================================
  Future<void> generateAndSaveCSV({
    required List<ChannelDataPoint> data,
    required List<dynamic> channels,
    required String fileName,
    required String reportDuration,
    required String dataGranularity,
  }) async {
    List<List<dynamic>> rows = [];
    rows.add(["Report Duration:", reportDuration]);
    rows.add(["Granularity:", dataGranularity]);
    rows.add([]);

    List<String> headers = ['Date Time'];
    for(var c in channels) headers.add(c['ChannelName']?.toString() ?? 'CH');
    rows.add(headers);

    List<String> unitRow = ['YYYY-MM-DD HH:mm'];
    for(var c in channels) unitRow.add(c['Unit']?.toString() ?? '-');
    rows.add(unitRow);

    for (var point in data) {
      List<dynamic> row = [DateFormat('yyyy-MM-dd HH:mm:ss').format(point.dateTime)];
      for (var c in channels) {
        String id = c['ChannelRecNo'].toString();
        row.add(point.values[id] ?? 0.0);
      }
      rows.add(row);
    }

    String csv = const ListToCsvConverter().convert(rows);
    await _saveFile(Uint8List.fromList(utf8.encode(csv)), fileName, "csv", MimeType.csv);
  }

  // ===========================================================================
  // DOCX GENERATION (MANUAL XML WITH IMAGE + HEADER/FOOTER TEXT)
  // ===========================================================================
  Future<void> generateAndSaveDOC({
    required List<ChannelDataPoint> data,
    required List<dynamic> channels,
    required Map<String, dynamic> branding,
    required List<String> headerLines, // --- Passed from UI
    required List<String> footerLines, // --- Passed from UI
    required String fileName,
    required String reportDuration,
    required String dataGranularity,
    Uint8List? graphImage,
  }) async {
    final archive = Archive();
    final StringBuffer xml = StringBuffer();
    final StringBuffer rels = StringBuffer(); // For document.xml.rels

    // 1. Start Relationship XML
    rels.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    rels.write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');

    // 2. Start Main Document XML
    xml.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    xml.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">');
    xml.write('<w:body>');

    // 3. Title & Branding
    _addXmlParagraph(xml, branding['name']?.toString() ?? "Report", fontSize: 36, isBold: true);
    _addXmlParagraph(xml, branding['address']?.toString() ?? "", fontSize: 20, color: "666666");
    _addXmlParagraph(xml, "");

    // 4. Metadata
    _addXmlParagraph(xml, reportDuration, isBold: true);
    _addXmlParagraph(xml, dataGranularity, isBold: true);
    _addXmlParagraph(xml, "");

    // 5. [NEW] CUSTOM HEADER LINES (Above Table)
    if (headerLines.isNotEmpty) {
      for (var line in headerLines) {
        if(line.isNotEmpty) _addXmlParagraph(xml, line, fontSize: 20);
      }
      _addXmlParagraph(xml, ""); // Spacer
    }

    // 6. EMBED GRAPH IMAGE (If Present)
    if (graphImage != null) {
      archive.addFile(ArchiveFile('word/media/image1.png', graphImage.length, graphImage));
      rels.write('<Relationship Id="rIdGraph1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image1.png"/>');

      int cx = 5715000; // ~600px width
      int cy = 2857500; // ~300px height

      xml.write('<w:p>');
      xml.write('<w:pPr><w:jc w:val="center"/></w:pPr>');
      xml.write('<w:r>');
      xml.write('<w:drawing>');
      xml.write('<wp:inline distT="0" distB="0" distL="0" distR="0">');
      xml.write('<wp:extent cx="$cx" cy="$cy"/>');
      xml.write('<wp:effectExtent l="0" t="0" r="0" b="0"/>');
      xml.write('<wp:docPr id="1" name="GraphImage"/>');
      xml.write('<wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>');
      xml.write('<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">');
      xml.write('<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">');

      xml.write('<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">');
      xml.write('<pic:nvPicPr>');
      xml.write('<pic:cNvPr id="1" name="image1.png"/>');
      xml.write('<pic:cNvPicPr/>');
      xml.write('</pic:nvPicPr>');

      xml.write('<pic:blipFill>');
      xml.write('<a:blip r:embed="rIdGraph1"/>');
      xml.write('<a:stretch><a:fillRect/></a:stretch>');
      xml.write('</pic:blipFill>');

      xml.write('<pic:spPr>');
      xml.write('<a:xfrm><a:off x="0" y="0"/><a:ext cx="$cx" cy="$cy"/></a:xfrm>');
      xml.write('<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>');
      xml.write('</pic:spPr>');

      xml.write('</pic:pic>');
      xml.write('</a:graphicData>');
      xml.write('</a:graphic>');
      xml.write('</wp:inline>');
      xml.write('</w:drawing>');
      xml.write('</w:r>');
      xml.write('</w:p>');

      _addXmlParagraph(xml, ""); // Spacer after image
    }

    // 7. Table Generation
    xml.write('<w:tbl>');

    // Borders
    xml.write('<w:tblPr><w:tblBorders>');
    xml.write('<w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    xml.write('<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    xml.write('<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    xml.write('<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    xml.write('<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    xml.write('<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>');
    xml.write('</w:tblBorders></w:tblPr>');

    // Headers
    xml.write('<w:tr>');
    _addXmlCell(xml, "Date Time", isHeader: true);
    for (var c in channels) {
      _addXmlCell(xml, c['ChannelName']?.toString() ?? "CH", isHeader: true);
    }
    xml.write('</w:tr>');

    // Units
    xml.write('<w:tr>');
    _addXmlCell(xml, "YYYY-MM-DD HH:mm", isUnit: true);
    for (var c in channels) {
      _addXmlCell(xml, c['Unit']?.toString() ?? "-", isUnit: true);
    }
    xml.write('</w:tr>');

    // Data
    for (int i = 0; i < data.length; i++) {
      xml.write('<w:tr>');
      _addXmlCell(xml, DateFormat('yyyy-MM-dd HH:mm').format(data[i].dateTime));
      for (var c in channels) {
        String id = c['ChannelRecNo'].toString();
        var val = data[i].values[id];
        String txt = val != null ? (val as num).toStringAsFixed(2) : "0.00";
        _addXmlCell(xml, txt);
      }
      xml.write('</w:tr>');
      if (i % 500 == 0) await Future.delayed(Duration.zero);
    }

    xml.write('</w:tbl>');

    // 8. [NEW] CUSTOM FOOTER LINES (After Table)
    if (footerLines.isNotEmpty) {
      _addXmlParagraph(xml, ""); // Spacer before footer
      for (var line in footerLines) {
        if(line.isNotEmpty) _addXmlParagraph(xml, line, fontSize: 18, color: "666666"); // Grey text
      }
    }

    // Close Body/Doc
    xml.write('</w:body>');
    xml.write('</w:document>');

    // 9. Finalize Relationships
    rels.write('</Relationships>');

    // 10. Build ZIP Structure

    // [Content_Types].xml
    archive.addFile(ArchiveFile('[Content_Types].xml', 0, utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Default Extension="png" ContentType="image/png"/>'
            '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
            '</Types>'
    )));

    // _rels/.rels (System Relationship)
    archive.addFile(ArchiveFile('_rels/.rels', 0, utf8.encode(
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
            '</Relationships>'
    )));

    // word/_rels/document.xml.rels
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', 0, utf8.encode(rels.toString())));

    // word/document.xml
    archive.addFile(ArchiveFile('word/document.xml', 0, utf8.encode(xml.toString())));

    // 11. Encode and Save
    final List<int>? zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      await _saveFile(Uint8List.fromList(zipData), fileName, "docx", MimeType.microsoftWord);
    }
  }

  // --- XML Helper Methods ---
  void _addXmlParagraph(StringBuffer xml, String text, {double fontSize = 22, bool isBold = false, String color = "000000"}) {
    xml.write('<w:p>');
    xml.write('<w:pPr>');
    if (isBold) xml.write('<w:b/>');
    xml.write('<w:color w:val="$color"/>');
    xml.write('<w:sz w:val="$fontSize"/>');
    xml.write('</w:pPr>');
    xml.write('<w:r><w:rPr>');
    if (isBold) xml.write('<w:b/>');
    xml.write('<w:sz w:val="$fontSize"/>');
    xml.write('</w:rPr><w:t>${_escapeXml(text)}</w:t></w:r>');
    xml.write('</w:p>');
  }

  void _addXmlCell(StringBuffer xml, String text, {bool isHeader = false, bool isUnit = false}) {
    String bgColor = isHeader ? "4472C4" : (isUnit ? "D9E1F2" : "auto");
    String textColor = isHeader ? "FFFFFF" : "000000";

    xml.write('<w:tc>');
    xml.write('<w:tcPr>');
    if (isHeader || isUnit) xml.write('<w:shd w:val="clear" w:color="auto" w:fill="$bgColor"/>');
    xml.write('<w:tcMar><w:top w:w="50" w:type="dxa"/><w:bottom w:w="50" w:type="dxa"/></w:tcMar>');
    xml.write('</w:tcPr>');

    xml.write('<w:p>');
    xml.write('<w:pPr><w:jc w:val="center"/></w:pPr>');
    xml.write('<w:r>');
    xml.write('<w:rPr>');
    if(isHeader) xml.write('<w:b/>');
    xml.write('<w:color w:val="$textColor"/>');
    xml.write('<w:sz w:val="18"/>');
    xml.write('</w:rPr>');
    xml.write('<w:t>${_escapeXml(text)}</w:t>');
    xml.write('</w:r>');
    xml.write('</w:p>');
    xml.write('</w:tc>');
  }

  String _escapeXml(String text) {
    return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  }

  // ===========================================================================
  // FILE SAVING & UTILS
  // ===========================================================================
  Future<void> _saveFile(Uint8List bytes, String fileName, String extension, MimeType type) async {
    try {
      if (kIsWeb) {
        await FileSaver.instance.saveFile(name: fileName, bytes: bytes, fileExtension: extension, mimeType: type);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final reportDir = Directory('${directory.path}/Reports');
        if (!await reportDir.exists()) await reportDir.create(recursive: true);

        final path = "${reportDir.path}/$fileName.$extension";
        final file = File(path);
        await file.writeAsBytes(bytes, flush: true);
        await Future.delayed(const Duration(milliseconds: 300));
        await OpenFilex.open(path);
      }
    } catch (e) {
      debugPrint("File Saving Error: $e");
      rethrow;
    }
  }

  Future<List<FileSystemEntity>> getDownloadedFiles() async {
    if (kIsWeb) return [];
    final directory = await getApplicationDocumentsDirectory();
    final reportDir = Directory('${directory.path}/Reports');
    if (await reportDir.exists()) {
      final files = reportDir.listSync();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return files;
    }
    return [];
  }
}