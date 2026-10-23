import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../config/constants/app_constants.dart';
import 'pdf_generator.dart';

/// Reusable helper for consistent calculator export (PDF) and sharing (Text & PDF)
class CalculatorShareHelper {
  static bool _isExporting = false;

  /// Optional injected SharePlus instance for testing.
  @visibleForTesting
  static SharePlus? sharePlusInstance;

  /// Optional injected output directory for testing.
  @visibleForTesting
  static Directory? testOutputDir;

  static SharePlus get _sharePlus => sharePlusInstance ?? SharePlus.instance;

  /// Exports the calculation results as a PDF document and opens the system share sheet.
  static Future<void> exportPdf({
    required BuildContext context,
    required String title,
    required Map<String, String> inputs,
    required Map<String, String> results,
    Directory? outputDir,
  }) async {
    if (_isExporting) return;
    _isExporting = true;

    try {
      final File file = await PdfGenerator.generateReport(
        title: title,
        inputs: inputs,
        results: results,
        outputDir: outputDir ?? testOutputDir,
      );

      if (!context.mounted) return;

      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final xFile = XFile(
        file.path,
        mimeType: 'application/pdf',
        name: 'FeroCalc_${safeTitle}_Report.pdf',
      );

      await _sharePlus.share(
        ShareParams(
          files: [xFile],
          subject: 'FeroCalc - $title Report',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report exported!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isExporting = false;
    }
  }

  /// Formats calculator inputs and results into clean shareable text.
  static String formatShareText({
    required String title,
    required Map<String, String> inputs,
    required Map<String, String> results,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('FeroCalc $title\n');
    for (final entry in inputs.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    for (final entry in results.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    buffer.writeln('\nDownload FeroCalc for more!');
    return buffer.toString().trim();
  }

  /// Formats calculator inputs and results into clean text and shares via system sheet.
  static Future<void> shareText({
    required BuildContext context,
    required String title,
    required Map<String, String> inputs,
    required Map<String, String> results,
  }) async {
    try {
      final text = formatShareText(
        title: title,
        inputs: inputs,
        results: results,
      );

      await _sharePlus.share(
        ShareParams(
          text: text,
          subject: 'FeroCalc - $title',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Formats calculator schedule inputs, summary, and table rows into clean shareable text.
  static String formatScheduleShareText({
    required String title,
    String? scheduleTitle,
    required Map<String, String> inputs,
    required Map<String, String> summary,
    required List<String> tableHeaders,
    required List<List<String>> tableRows,
    String? disclaimer,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('FeroCalc $title\n');
    if (inputs.isNotEmpty) {
      buffer.writeln('Inputs:');
      for (final entry in inputs.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
      buffer.writeln();
    }
    if (summary.isNotEmpty) {
      buffer.writeln('Summary:');
      for (final entry in summary.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
      buffer.writeln();
    }
    final effectiveTitle = scheduleTitle ??
        (title.contains('SSY') || title.contains('Sukanya')
            ? 'Year-wise Schedule'
            : 'Repayment Schedule');
    buffer.writeln('$effectiveTitle:');
    buffer.writeln(tableHeaders.join(' | '));
    for (final row in tableRows) {
      buffer.writeln(row.join(' | '));
    }
    if (disclaimer != null && disclaimer.isNotEmpty) {
      buffer.writeln('\n$disclaimer');
    } else {
      buffer.writeln(
        '\nDisclaimer: Results are for informational purposes only. Not financial advice.',
      );
    }
    buffer.writeln('Download FeroCalc for more!');
    return buffer.toString().trim();
  }

  /// Exports a detailed calculation schedule as a PDF document and opens the system share sheet.
  static Future<void> exportSchedulePdf({
    required BuildContext context,
    required String title,
    String subtitle = '',
    String? scheduleSectionTitle,
    required Map<String, String> inputs,
    required Map<String, String> summary,
    required List<String> tableHeaders,
    required List<List<String>> tableRows,
    String? disclaimer,
    Map<int, pw.Alignment>? columnAlignments,
    Directory? outputDir,
  }) async {
    if (_isExporting) return;
    _isExporting = true;

    try {
      final File file = await PdfGenerator.generateScheduleReport(
        title: title,
        subtitle: subtitle,
        scheduleSectionTitle: scheduleSectionTitle,
        inputs: inputs,
        summary: summary,
        tableHeaders: tableHeaders,
        tableRows: tableRows,
        disclaimer: disclaimer,
        columnAlignments: columnAlignments,
        outputDir: outputDir ?? testOutputDir,
      );

      if (!context.mounted) return;

      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final xFile = XFile(
        file.path,
        mimeType: 'application/pdf',
        name: 'FeroCalc_${safeTitle}_Schedule.pdf',
      );

      await _sharePlus.share(
        ShareParams(
          files: [xFile],
          subject: 'FeroCalc - $title Schedule',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule PDF exported!'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isExporting = false;
    }
  }

  /// Formats schedule into text and shares via system sheet.
  static Future<void> shareScheduleText({
    required BuildContext context,
    required String title,
    String? scheduleTitle,
    required Map<String, String> inputs,
    required Map<String, String> summary,
    required List<String> tableHeaders,
    required List<List<String>> tableRows,
    String? disclaimer,
  }) async {
    try {
      final text = formatScheduleShareText(
        title: title,
        scheduleTitle: scheduleTitle,
        inputs: inputs,
        summary: summary,
        tableHeaders: tableHeaders,
        tableRows: tableRows,
        disclaimer: disclaimer,
      );

      await _sharePlus.share(
        ShareParams(
          text: text,
          subject: 'FeroCalc - $title Schedule',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Formats the promotional share message for the FeroCalc app.
  static String formatAppShareText() {
    return 'FeroCalc - All-in-one Financial & Investment Calculator\n\n'
        'Calculate SIP, EMI, FD, RD, PPF, NPS, Income Tax and compare bank interest rates easily.\n\n'
        'Download FeroCalc: ${AppConstants.playStoreUrl}';
  }

  /// Summons the platform\'s native share sheet to promote and share the FeroCalc app.
  static Future<void> shareApp(BuildContext context) async {
    try {
      final text = formatAppShareText();
      await _sharePlus.share(
        ShareParams(
          text: text,
          subject: 'FeroCalc - Financial & Loan Calculator',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share app: $e'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
