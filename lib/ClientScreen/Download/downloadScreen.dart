// lib/ClientScreen/Download/downloadScreen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../ClinetService/export_service.dart';
import '../../theme/client_theme.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final ExportService _exportService = ExportService();
  final TextEditingController _searchController = TextEditingController();

  List<FileSystemEntity> _allFiles = [];
  List<FileSystemEntity> _filteredFiles = [];

  bool _isLoading = true;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    final files = await _exportService.getDownloadedFiles();
    if (!mounted) return;
    setState(() {
      _allFiles = files;
      _filteredFiles = files;
      _isLoading = false;
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFiles = _allFiles.where((file) {
        final fileName = file.path.split('/').last.toLowerCase();
        final fileDate = file.statSync().modified;

        final matchesSearch = fileName.contains(query);

        bool matchesDate = true;
        if (_selectedDate != null) {
          matchesDate = fileDate.year == _selectedDate!.year &&
              fileDate.month == _selectedDate!.month &&
              fileDate.day == _selectedDate!.day;
        }

        return matchesSearch && matchesDate;
      }).toList();
    });
  }

  // Date hatane ka function
  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
    _applyFilters();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: ClientTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      _applyFilters();
    }
  }

  Future<void> _confirmDelete(FileSystemEntity file) async {
    final fileName = file.path.split('/').last;
    final bool? delete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Report?"),
        content: Text("Are you sure you want to delete '$fileName'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (delete == true) {
      try {
        await file.delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File deleted")));
        _loadFiles();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
      }
    }
  }

  Future<void> _openFile(String path) async {
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot open file: ${result.message}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Generated Reports"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildInspiredSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFiles.isEmpty
                ? _buildEmptyState()
                : _buildFileList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInspiredSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: ClientTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClientTheme.textLight.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: ClientTheme.textDark.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5)
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search Reports...',
                  hintStyle: TextStyle(color: ClientTheme.textLight.withOpacity(0.6), fontSize: 15),
                  prefixIcon: Icon(Iconsax.search_normal, color: ClientTheme.primaryColor, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                      icon: Icon(Iconsax.close_circle, color: ClientTheme.textLight, size: 18),
                      onPressed: () { _searchController.clear(); setState(() {}); }
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            // Agar date selected hai to "Remove" button dikhega, warna "Calendar"
            _selectedDate != null
                ? IconButton(
              onPressed: _clearDateFilter,
              icon: const Icon(Iconsax.calendar_remove, color: Colors.red, size: 20),
              tooltip: "Clear Date Filter",
            )
                : IconButton(
              onPressed: _pickDate,
              icon: Icon(Iconsax.calendar, color: ClientTheme.textLight, size: 20),
              tooltip: "Filter by Date",
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: ClientTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)
              ),
              child: Text(
                  '${_filteredFiles.length}',
                  style: TextStyle(
                    color: ClientTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  )
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              _selectedDate != null || _searchController.text.isNotEmpty
                  ? Iconsax.search_status
                  : Iconsax.folder_open,
              size: 48,
              color: ClientTheme.textLight
          ),
          const SizedBox(height: 16),
          Text(
              "No reports found",
              style: TextStyle(fontSize: 18, color: ClientTheme.textDark, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your search or date filter.",
            style: TextStyle(color: ClientTheme.textLight),
          ),
          if (_selectedDate != null || _searchController.text.isNotEmpty)
            TextButton(
                onPressed: () {
                  _searchController.clear();
                  _clearDateFilter();
                },
                child: const Text("Clear All Filters", style: TextStyle(color: Colors.red))
            )
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: _filteredFiles.length,
      itemBuilder: (ctx, i) {
        final file = _filteredFiles[i];
        final name = file.path.split('/').last;
        final stat = file.statSync();

        final isPdf = name.toLowerCase().endsWith(".pdf");
        final isExcel = name.toLowerCase().endsWith(".xlsx");
        final isDoc = name.toLowerCase().endsWith(".html") || name.toLowerCase().endsWith(".doc");

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: ClientTheme.textLight.withOpacity(0.05)),
          ),
          child: ListTile(
            onLongPress: () => _confirmDelete(file), // DELETE ON LONG PRESS
            onTap: () => _openFile(file.path),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isPdf ? Colors.red : (isExcel ? Colors.green : Colors.blue)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf ? Iconsax.document : (isExcel ? Iconsax.document_text : (isDoc ? Iconsax.document_text_1 : Iconsax.document_code)),
                color: isPdf ? Colors.red : (isExcel ? Colors.green : (isDoc ? Colors.indigo : Colors.blue)),
                size: 20,
              ),
            ),
            title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              "${(stat.size / 1024).toStringAsFixed(1)} KB • ${DateFormat('MMM d, HH:mm').format(stat.modified)}",
              style: TextStyle(fontSize: 11, color: ClientTheme.textLight),
            ),
            trailing: const Icon(Iconsax.arrow_right_3, size: 14),
          ),
        );
      },
    );
  }
}