import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareTextAsFile({
  required String content,
  required String fileName,
  required String subject,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: subject),
  );
}
