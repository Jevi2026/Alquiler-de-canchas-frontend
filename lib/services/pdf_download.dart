import 'pdf_download_stub.dart'
    if (dart.library.html) 'pdf_download_web.dart' as platform;

void savePdf(List<int> bytes, String filename) => platform.savePdf(bytes, filename);
