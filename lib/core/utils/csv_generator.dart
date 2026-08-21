import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class CsvGenerator {
  static Future<File> generateCsv({
    required Map<String, String> data,
    required String fileName,
  }) async {
    List<List<dynamic>> rows = [];
    rows.add(['Parameter', 'Value']); // Header

    data.forEach((key, value) {
      rows.add([key, value]);
    });

    String csv = const ListToCsvConverter().convert(rows);

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$fileName.csv');
    await file.writeAsString(csv);
    return file;
  }
}
