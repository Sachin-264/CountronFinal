// lib/screens/download_history_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:open_filex/open_filex.dart';
import '../../ClinetService/export_service.dart';
import '../../theme/client_theme.dart';

class DownloadHistoryScreen extends StatefulWidget {
  const DownloadHistoryScreen({super.key});

  @override
  State<DownloadHistoryScreen> createState() => _DownloadHistoryScreenState();
}

class _DownloadHistoryScreenState extends State<DownloadHistoryScreen> {
  final ExportService _exportService = ExportService();
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    final files = await _exportService.getDownloadedFiles();
    setState(() {
      _files = files;
      _isLoading = false;
    });
  }

  Future<void> _openFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cannot open file: ${result.message}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Generated Reports")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Iconsax.folder_open, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text("No reports generated yet.", style: TextStyle(color: Colors.grey))
      ]))
          : ListView.builder(
        itemCount: _files.length,
        itemBuilder: (ctx, i) {
          final file = _files[i];
          final name = file.path.split('/').last;
          final stat = file.statSync();
          final isPdf = name.endsWith(".pdf");
          final isExcel = name.endsWith(".xlsx");

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                isPdf ? Iconsax.document : (isExcel ? Iconsax.document_text : Iconsax.document_code),
                color: isPdf ? Colors.red : (isExcel ? Colors.green : Colors.blue),
                size: 32,
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text("Size: ${(stat.size / 1024).toStringAsFixed(1)} KB"),
              trailing: const Icon(Iconsax.arrow_right_3, size: 16),
              onTap: () => _openFile(file.path),
            ),
          );
        },
      ),
    );
  }
}