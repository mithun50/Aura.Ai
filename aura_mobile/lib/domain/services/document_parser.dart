import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';

/// Interface for document parsers
abstract class DocumentParser {
  Future<String> parse(File file);
}

/// PDF parser using read_pdf_text
class PdfParser implements DocumentParser {
  @override
  Future<String> parse(File file) async {
    try {
      return await ReadPdfText.getPDFtext(file.path);
    } catch (e) {
      if (kDebugMode) debugPrint('Error reading PDF: $e');
      return '';
    }
  }
}

/// Plain text parser
class TxtParser implements DocumentParser {
  @override
  Future<String> parse(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      if (kDebugMode) debugPrint('Error reading TXT: $e');
      return '';
    }
  }
}

/// DOCX parser using docx_to_text
class DocxParser implements DocumentParser {
  @override
  Future<String> parse(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return docxToText(bytes);
    } catch (e) {
      if (kDebugMode) debugPrint('Error reading DOCX: $e');
      return '';
    }
  }
}

/// Spreadsheet parser (XLSX/XLS) using excel package
class SpreadsheetParser implements DocumentParser {
  @override
  Future<String> parse(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final extension = file.path.split('.').last.toLowerCase();

      if (extension == 'csv') {
        return _parseCsv(await file.readAsString());
      }

      final excel = Excel.decodeBytes(bytes);
      final buffer = StringBuffer();

      for (final sheet in excel.tables.keys) {
        buffer.writeln('Sheet: $sheet');
        final table = excel.tables[sheet]!;
        for (final row in table.rows) {
          final cells = row.map((cell) => cell?.value?.toString() ?? '').join('\t');
          buffer.writeln(cells);
        }
        buffer.writeln('');
      }

      return buffer.toString();
    } catch (e) {
      if (kDebugMode) debugPrint('Error reading spreadsheet: $e');
      return '';
    }
  }

  String _parseCsv(String csvContent) {
    try {
      final rows = const CsvToListConverter().convert(csvContent);
      final buffer = StringBuffer();
      for (final row in rows) {
        buffer.writeln(row.map((cell) => cell.toString()).join('\t'));
      }
      return buffer.toString();
    } catch (e) {
      return csvContent;
    }
  }
}

/// Factory to get the right parser based on file extension
class DocumentParserFactory {
  static DocumentParser? getParser(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return PdfParser();
      case 'txt':
      case 'md':
      case 'log':
        return TxtParser();
      case 'docx':
      case 'doc':
        return DocxParser();
      case 'xlsx':
      case 'xls':
        return SpreadsheetParser();
      case 'csv':
        return SpreadsheetParser();
      default:
        return null;
    }
  }

  static List<String> get supportedExtensions =>
      ['pdf', 'txt', 'docx', 'xlsx', 'xls', 'csv'];
}
