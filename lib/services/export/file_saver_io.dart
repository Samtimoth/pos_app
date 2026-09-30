import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile / desktop: write to a temp file and open the system share sheet
/// (WhatsApp, email, Drive, "save to files"…).
Future<String> saveAndShare(String filename, List<int> bytes,
    {String subject = ''}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
    subject: subject,
  );
  return file.path;
}
