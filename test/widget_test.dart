import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nas_photo_manager/main.dart';
import 'package:nas_photo_manager/screens/help_screen.dart';
import 'package:nas_photo_manager/screens/tutorial_screen.dart';
import 'package:nas_photo_manager/services/webdav_service.dart';
import 'package:nas_photo_manager/theme.dart';

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

    test('default URL points at the /dav endpoint behind the proxy', () {
      expect(
        WebdavService.defaultUrl,
        'https://your-nas.your-tailnet.ts.net:8443/dav',
      );
    });

    test('keeps the /dav path while stripping trailing slashes', () {
      expect(
        WebdavService.normalizeUrl('https://your-nas.your-tailnet.ts.net:8443/dav/'),
        'https://your-nas.your-tailnet.ts.net:8443/dav',
      );
    });

    test('fileUrl appends encoded photo paths under /dav', () {
      final service = WebdavService();
      expect(
        service.fileUrl('/uploads/photo one.jpg'),
        'https://your-nas.your-tailnet.ts.net:8443/dav/uploads/photo%20one.jpg',
      );
      expect(
        service.fileUrl('/file.jpg'),
        'https://your-nas.your-tailnet.ts.net:8443/dav/file.jpg',
      );
    });
  });

  group('TutorialScreen', () {
    testWidgets('shows the five steps with an in-memory checklist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: OneDriveTheme.light, home: const TutorialScreen()),
      );

      expect(find.text('Getting started'), findsOneWidget);
      expect(find.text('0 of 5 done'), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);

      await tester.tap(find.text('Welcome'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 5 done'), findsOneWidget);

      await tester.tap(find.text('Welcome'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 5 done'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Stay private'), 300);
      expect(find.text('Stay private'), findsOneWidget);
    });
  });

  group('HelpScreen', () {
    testWidgets('lists the FAQ, diagnostics and support footer', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OneDriveTheme.light,
          home: HelpScreen(webdavService: WebdavService()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Frequently asked questions'), findsOneWidget);
      expect(find.text("Can't connect to the NAS"), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Support: contact your NAS administrator.'),
        300,
      );
      expect(
        find.text('Support: contact your NAS administrator.'),
        findsOneWidget,
      );
    });
  });

  group('HomeShell navigation', () {
    testWidgets('exposes the five OneDrive-style destinations', (tester) async {
      await tester.pumpWidget(
        NasPhotoManagerApp(webdavService: WebdavService()),
      );
      // The galleries run their plugin-backed init work; a single frame is
      // enough to mount the shell (loading spinners keep animating).
      await tester.pump(const Duration(milliseconds: 100));

      final Finder navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);
      for (final String label in <String>[
        'NAS Photos',
        'Local Photos',
        'Tutorial',
        'Help',
        'Settings',
      ]) {
        expect(
          find.descendant(of: navBar, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(tester.widget<NavigationBar>(navBar).selectedIndex, 0);

      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Tutorial')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<NavigationBar>(navBar).selectedIndex, 2);
      expect(find.text('Getting started'), findsOneWidget);
    });
  });
}
