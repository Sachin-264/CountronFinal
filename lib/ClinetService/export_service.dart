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
import '../ClientScreen/ViewData/channel_data_model.dart';

class ExportService {
  static const String _imageBaseUrl = "https://storage.googleapis.com/upload-images-34/images/LMS/";

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
  }) async {
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: ttf,
        bold: ttf,
      ),
    );

    final pageOrientation = orientation == 'Landscape'
        ? pw.PageOrientation.landscape
        : pw.PageOrientation.portrait;

    pw.MemoryImage? logoImage;
    if (branding['logoPath'] != null && branding['logoPath'].isNotEmpty) {
      try {
        final response = await http.get(Uri.parse("$_imageBaseUrl${branding['logoPath']}"));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint("Error loading logo for PDF: $e");
      }
    }

    pw.MemoryImage? graphMemImage;
    if (graphImage != null) {
      graphMemImage = pw.MemoryImage(graphImage);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        orientation: pageOrientation,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildPdfHeader(context, branding, headerLines, logoImage, reportDuration, dataGranularity),
        footer: (context) => _buildPdfFooter(context, footerLines),
        build: (context) => [
          if (graphMemImage != null) ...[
            pw.Text("Trend Analysis Graph", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Image(graphMemImage, width: pageOrientation == pw.PageOrientation.landscape ? 700 : 450),
            ),
            pw.SizedBox(height: 20),
          ],
          _buildPdfTable(data, channels),
        ],
      ),
    );

    await _saveFile(await pdf.save(), fileName, "pdf", MimeType.pdf);
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
                pw.Text(branding['name'] ?? "Company Name", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(branding['address'] ?? "Address", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
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

  pw.Widget _buildPdfTable(List<ChannelDataPoint> data, List<dynamic> channels) {
    final headers = ['Date Time', ...channels.map((e) => e['ChannelName'].toString())];

    // --- [UPDATE] Unit Row Logic (Changed Text) ---
    final List<String> unitRow = ['YYYY-MM-DD HH:mm'];
    for (var c in channels) {
      unitRow.add(c['Unit']?.toString() ?? '-');
    }

    // --- Data Rows ---
    final dataRows = data.map((point) {
      List<String> row = [DateFormat('yyyy-MM-dd HH:mm').format(point.dateTime)];
      for (var c in channels) {
        String id = c['ChannelRecNo'].toString();
        row.add(point.values[id]?.toStringAsFixed(2) ?? "0.00");
      }
      return row;
    }).toList();

    // Insert Unit Row at the very beginning of the data rows
    dataRows.insert(0, unitRow);

    return pw.Table.fromTextArray(
      headers: headers,
      data: dataRows,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      // Styling the unit row differently (it's now row 0 of data)
      rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  // --- UPGRADED EXCEL METHOD (Using Syncfusion) ---
  Future<void> generateAndSaveExcel({
    required List<ChannelDataPoint> data,
    required List<dynamic> channels,
    required Map<String, dynamic> branding,
    required String fileName,
    required String reportDuration,
    required String dataGranularity,
    Uint8List? graphImage,
  }) async {
    final xlsio.Workbook workbook = xlsio.Workbook();
    final xlsio.Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Report';

    // Page Setup
    sheet.pageSetup.orientation = xlsio.ExcelPageOrientation.landscape;
    sheet.pageSetup.topMargin = 0.5;
    sheet.pageSetup.bottomMargin = 0.5;

    // Styles
    final xlsio.Style headerStyle = workbook.styles.add('HeaderStyle')
      ..fontName = 'Arial'..fontSize = 18..bold = true..hAlign = xlsio.HAlignType.left;
    final xlsio.Style subHeaderStyle = workbook.styles.add('SubHeaderStyle')
      ..fontName = 'Arial'..fontSize = 11..hAlign = xlsio.HAlignType.left..wrapText = true;
    final xlsio.Style metadataStyle = workbook.styles.add('MetadataStyle')
      ..fontName = 'Arial'..fontSize = 10..bold = true;
    final xlsio.Style tableHeaderStyle = workbook.styles.add('TableHeaderStyle')
      ..fontName = 'Arial'..fontSize = 11..bold = true..backColor = '#D9E1F2'
      ..hAlign = xlsio.HAlignType.center..borders.all.lineStyle = xlsio.LineStyle.thin;
    final xlsio.Style unitRowStyle = workbook.styles.add('UnitRowStyle')
      ..fontName = 'Arial'..fontSize = 10..bold = true..backColor = '#F2F2F2'
      ..hAlign = xlsio.HAlignType.center..borders.all.lineStyle = xlsio.LineStyle.thin;
    final xlsio.Style normalStyle = workbook.styles.add('NormalStyle')
      ..fontName = 'Arial'..fontSize = 10..borders.all.lineStyle = xlsio.LineStyle.thin
      ..hAlign = xlsio.HAlignType.center;

    int currentRow = 1;

    // Logo & Company Info
    if (branding['logoPath'] != null && branding['logoPath'].isNotEmpty) {
      try {
        final response = await http.get(Uri.parse("$_imageBaseUrl${branding['logoPath']}"));
        if (response.statusCode == 200) {
          final xlsio.Picture picture = sheet.pictures.addStream(1, 1, response.bodyBytes);
          picture.height = 45;
          picture.width = 120;
        }
      } catch (e) { debugPrint("Excel Logo Error: $e"); }

      // Text next to logo (merged C1:H1)
      sheet.getRangeByName('C1:J1')..merge()..setText(branding['name'] ?? '')..cellStyle = headerStyle;
      sheet.getRangeByName('C2:J2')..merge()..setText(branding['address'] ?? '')..cellStyle = subHeaderStyle;
      currentRow = 4;
    } else {
      sheet.getRangeByName('A1:J1')..merge()..setText(branding['name'] ?? '')..cellStyle = headerStyle;
      sheet.getRangeByName('A2:J2')..merge()..setText(branding['address'] ?? '')..cellStyle = subHeaderStyle;
      currentRow = 4;
    }

    // Metadata
    sheet.getRangeByIndex(currentRow, 1).setText("Report Period: $reportDuration");
    sheet.getRangeByIndex(currentRow, 1).cellStyle = metadataStyle;
    currentRow++;
    sheet.getRangeByIndex(currentRow, 1).setText("Granularity: $dataGranularity");
    sheet.getRangeByIndex(currentRow, 1).cellStyle = metadataStyle;
    currentRow += 2;

    // Graph Section
    if (graphImage != null) {
      sheet.getRangeByIndex(currentRow, 1).setText("投 TREND ANALYSIS GRAPH");
      sheet.getRangeByIndex(currentRow, 1).cellStyle = metadataStyle;
      currentRow++;

      final xlsio.Picture picture = sheet.pictures.addStream(currentRow, 1, graphImage);
      picture.height = 350;
      picture.width = 700;
      currentRow += 18;
    }

    currentRow += 1;
    sheet.getRangeByIndex(currentRow, 1).setText("搭 DATA TABLE");
    sheet.getRangeByIndex(currentRow, 1).cellStyle = metadataStyle;
    currentRow += 2;

    // --- 1. Header Row ---
    int tableStartRow = currentRow;
    sheet.getRangeByIndex(tableStartRow, 1).setText("Date Time");
    for (int i = 0; i < channels.length; i++) {
      sheet.getRangeByIndex(tableStartRow, i + 2).setText(channels[i]['ChannelName'].toString());
    }
    sheet.getRangeByIndex(tableStartRow, 1, tableStartRow, channels.length + 1).cellStyle = tableHeaderStyle;
    sheet.setRowHeightInPixels(tableStartRow, 25);

    // --- 2. [UPDATE] Unit Row (Changed Text) ---
    int unitRowIdx = tableStartRow + 1;
    sheet.getRangeByIndex(unitRowIdx, 1).setText("YYYY-MM-DD HH:mm");
    for (int i = 0; i < channels.length; i++) {
      sheet.getRangeByIndex(unitRowIdx, i + 2).setText(channels[i]['Unit']?.toString() ?? '-');
    }
    sheet.getRangeByIndex(unitRowIdx, 1, unitRowIdx, channels.length + 1).cellStyle = unitRowStyle;

    // --- 3. Data Rows ---
    for (int i = 0; i < data.length; i++) {
      // Start data AFTER unit row
      int rowIdx = unitRowIdx + 1 + i;
      sheet.getRangeByIndex(rowIdx, 1).setText(DateFormat('yyyy-MM-dd HH:mm:ss').format(data[i].dateTime));

      for (int c = 0; c < channels.length; c++) {
        String id = channels[c]['ChannelRecNo'].toString();
        double val = data[i].values[id] as double? ?? 0.0;
        sheet.getRangeByIndex(rowIdx, c + 2).setNumber(val);
      }
      sheet.getRangeByIndex(rowIdx, 1, rowIdx, channels.length + 1).cellStyle = normalStyle;
    }

    // Auto-fit Columns
    sheet.autoFitColumn(1);
    for(int i=0; i<channels.length; i++) {
      sheet.setColumnWidthInPixels(i+2, 100);
    }

    // Save
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    await _saveFile(Uint8List.fromList(bytes), fileName, "xlsx", MimeType.microsoftExcel);
  }

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

    // Header Row
    List<String> headers = ['Date Time'];
    for(var c in channels) headers.add(c['ChannelName']);
    rows.add(headers);

    // --- [UPDATE] Unit Row (Changed Text) ---
    List<String> unitRow = ['YYYY-MM-DD HH:mm'];
    for(var c in channels) unitRow.add(c['Unit']?.toString() ?? '-');
    rows.add(unitRow);

    // Data Rows
    for (var point in data) {
      List<dynamic> row = [DateFormat('yyyy-MM-dd HH:mm:ss').format(point.dateTime)];
      for (var c in channels) {
        String id = c['ChannelRecNo'].toString();
        row.add(point.values[id] ?? 0.0);
      }
      rows.add(row);
    }

    String csv = const ListToCsvConverter().convert(rows);
    await _saveFile(Uint8List.fromList(csv.codeUnits), fileName, "csv", MimeType.csv);
  }

  // --- UPGRADED WORD METHOD (Word-Compatible HTML) ---
  Future<void> generateAndSaveDOC({
    required List<ChannelDataPoint> data,
    required List<dynamic> channels,
    required Map<String, dynamic> branding,
    required String fileName,
    required String reportDuration,
    required String dataGranularity,
    Uint8List? graphImage,
  }) async {
    final StringBuffer html = StringBuffer();

    // 1. Doc Header & CSS (Crucial for Word formatting)
    html.writeln('<!DOCTYPE html>');
    html.writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word">');
    html.writeln('<head><meta charset="utf-8"><title>Report</title>');
    html.writeln('''
    <style>
      @page { size: A4 landscape; margin: 0.5in; }
      body { font-family: Arial, sans-serif; font-size: 10pt; line-height: 1.2; }
      .header-table { width: 100%; border-collapse: collapse; margin-bottom: 20pt; }
      .company-name { font-size: 16pt; font-weight: bold; color: #333; margin-bottom: 5px; }
      .company-address { font-size: 10pt; color: #666; }
      .section-title { font-size: 12pt; font-weight: bold; padding: 6pt; border: 1pt solid; margin-top: 20pt; width: 60%; }
      .graph-section { background-color: #E8F4FD; border-color: #4A90A4; color: #2C5F6F; }
      .table-section { background-color: #FFF2CC; border-color: #D6B656; color: #8B7315; }
      .data-table { width: 100%; border-collapse: collapse; margin-top: 10pt; font-size: 9pt; }
      .data-table th { background-color: #D9E1F2; border: 1pt solid #999; padding: 5pt; font-weight: bold; text-align: center; }
      .unit-row td { background-color: #F2F2F2; border: 1pt solid #999; padding: 5pt; font-weight: bold; text-align: center; font-style: italic; }
      .data-table td { border: 1pt solid #ccc; padding: 4pt; text-align: center; }
      .even-row { background-color: #f9f9f9; }
      .metadata { margin-bottom: 20px; font-weight: bold; font-size: 10pt; color: #444; }
    </style>
    ''');
    html.writeln('</head><body>');
    html.writeln('<div class="document">');

    // 2. Logo & Branding
    html.writeln('<table class="header-table"><tr>');
    if (branding['logoPath'] != null && branding['logoPath'].isNotEmpty) {
      try {
        final response = await http.get(Uri.parse("$_imageBaseUrl${branding['logoPath']}"));
        if (response.statusCode == 200) {
          final logoBase64 = base64Encode(response.bodyBytes);
          html.writeln('<td style="width: 100px; vertical-align: top;"><img width="100" height="50" src="data:image/png;base64,$logoBase64"></td>');
          html.writeln('<td style="padding-left: 15px; vertical-align: top;">');
        } else {
          html.writeln('<td colspan="2" style="text-align: center;">');
        }
      } catch (e) { html.writeln('<td colspan="2" style="text-align: center;">'); }
    } else {
      html.writeln('<td colspan="2" style="text-align: center;">');
    }
    html.writeln('<div class="company-name">${branding['name'] ?? ''}</div>');
    html.writeln('<div class="company-address">${branding['address'] ?? ''}</div>');
    html.writeln('</td></tr></table>');

    // 3. Metadata
    html.writeln('<div class="metadata">');
    html.writeln('<p>$reportDuration</p>');
    html.writeln('<p>$dataGranularity</p>');
    html.writeln('</div>');

    // 4. Graph
    if (graphImage != null) {
      final base64Graph = base64Encode(graphImage);
      html.writeln('<div class="section-title graph-section">投 TREND ANALYSIS</div>');
      html.writeln('<div style="margin-top: 10px; margin-bottom: 20px;"><img src="data:image/png;base64,$base64Graph" width="600" /></div>');
    }

    // 5. Data Table
    html.writeln('<div class="section-title table-section">搭 DATA TABLE</div>');
    html.writeln('<table class="data-table">');

    // Header Row
    html.writeln('<thead><tr><th>Date Time</th>');
    for(var c in channels) html.writeln('<th>${c['ChannelName']}</th>');
    html.writeln('</tr>');

    // --- [UPDATE] Unit Row (Changed Text) ---
    html.writeln('<tr class="unit-row"><td>YYYY-MM-DD HH:mm</td>');
    for(var c in channels) html.writeln('<td>${c['Unit'] ?? '-'}</td>');
    html.writeln('</tr>');

    html.writeln('</thead>');

    html.writeln('<tbody>');
    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final rowClass = i % 2 == 0 ? 'even-row' : 'odd-row';
      html.writeln('<tr class="$rowClass">');
      html.writeln('<td>${DateFormat('yyyy-MM-dd HH:mm:ss').format(point.dateTime)}</td>');
      for (var c in channels) {
        String id = c['ChannelRecNo'].toString();
        html.writeln('<td>${point.values[id]?.toStringAsFixed(2) ?? '-'}</td>');
      }
      html.writeln('</tr>');
    }
    html.writeln('</tbody></table>');

    html.writeln('</div></body></html>'); // Close doc

    await _saveFile(Uint8List.fromList(html.toString().codeUnits), fileName, "doc", MimeType.microsoftWord);
  }

  Future<void> _saveFile(Uint8List bytes, String fileName, String extension, MimeType type) async {
    try {
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: bytes,
          fileExtension: extension,
          mimeType: type,
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final reportDir = Directory('${directory.path}/Reports');
        if (!await reportDir.exists()) await reportDir.create(recursive: true);

        final path = "${reportDir.path}/$fileName.$extension";
        final file = File(path);
        await file.writeAsBytes(bytes);

        await OpenFilex.open(path);
      }
    } catch (e) {
      debugPrint("File Saving Error: $e");
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