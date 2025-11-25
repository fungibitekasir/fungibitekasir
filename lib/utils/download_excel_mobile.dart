import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';

Future<void> downloadExcelMobile(List<int> bytes, String fileName) async {
  final Uint8List uint8list = Uint8List.fromList(bytes);

  await FileSaver.instance.saveFile(
    name: fileName,
    bytes: uint8list,
    ext: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
}
