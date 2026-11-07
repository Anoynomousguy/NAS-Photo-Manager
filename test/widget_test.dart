import 'package:flutter_test/flutter_test.dart';
import 'package:nas_photo_manager/services/webdav_service.dart';

void main() {
  group('WebdavService URL handling', () {
    test('keeps an https URL and removes trailing slashes', () {
      expect(
        WebdavService.normalizeUrl('https://your-nas.your-tailnet.ts.net:8443///'),
        'https://your-nas.your-tailnet.ts.net:8443',
      );
    });

    test('adds https when the scheme is omitted', () {
      expect(
        WebdavService.normalizeUrl('your-nas.your-tailnet.ts.net:8443'),
        'https://your-nas.your-tailnet.ts.net:8443',
      );
    });

    test('rejects an empty URL', () {
      expect(
        () => WebdavService.normalizeUrl('   '),
        throwsA(isA<WebdavException>()),
      );
    });
  });
}
