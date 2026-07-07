import 'package:file_saver/file_saver.dart';

import '../network/api_client.dart';

/// Guarda el archivo descargado usando una implementación compatible con Web,
/// Android y Windows.
///
/// En Web, FileSaver activa la descarga del navegador. En Windows utiliza la
/// carpeta de descargas del sistema y en Android guarda el archivo mediante el
/// adaptador nativo del paquete.
Future<bool> saveDownloadedFile(DownloadedFile file) async {
  if (file.bytes.isEmpty) {
    throw const ApiException(
      'El reporte recibido está vacío.',
      code: 'REPORT_EMPTY_FILE',
    );
  }

  final parts = file.filename.split('.');
  final hasExtension = parts.length > 1 && parts.last.isNotEmpty;
  final extension = hasExtension ? parts.removeLast().toLowerCase() : '';
  final name = parts.join('.').trim().isEmpty
      ? 'smart-grid-validator-reporte'
      : parts.join('.').trim();

  final isPdf = extension == 'pdf' ||
      file.contentType.toLowerCase().contains('application/pdf');
  final contentType = file.contentType.split(';').first.trim();

  final result = await FileSaver.instance.saveFile(
    name: name,
    bytes: file.bytes,
    fileExtension: extension,
    includeExtension: extension.isNotEmpty,
    mimeType: isPdf ? MimeType.pdf : MimeType.custom,
    customMimeType: isPdf
        ? null
        : (contentType.isEmpty ? 'application/octet-stream' : contentType),
  );

  return result.isNotEmpty;
}
