import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nas_photo_manager/core/auth_context.dart';
import 'package:nas_photo_manager/core/module.dart';
import 'package:nas_photo_manager/core/network_status.dart';
import 'package:nas_photo_manager/core/route_guard.dart';
import 'package:nas_photo_manager/main.dart';
import 'package:nas_photo_manager/modules/manifest.dart';
import 'package:nas_photo_manager/screens/help_screen.dart';
import 'package:nas_photo_manager/screens/tutorial_screen.dart';
import 'package:nas_photo_manager/services/webdav_service.dart';
import 'package:nas_photo_manager/theme.dart';

Future<void> _pumpShell(WidgetTester tester, {required UserRole role}) async {
  final NetworkStatusController network = NetworkStatusController(
    interval: const Duration(hours: 1),
    probe: () async => true,
  );
  addTearDown(network.dispose);

  await tester.pumpWidget(
    NasPhotoManagerApp(
      webdavService: WebdavService(),
      auth: AuthContext(
        role: role,
        username: role == UserRole.admin ? 'Admin' : 'Member',
      ),
      networkStatus: network,
    ),
  );
  await tester.pump();
  // Let the initial shell skeleton finish its reveal and fade-out.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 320));
}

Finder _navLabel(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

void main() {
  group('WebdavService URL handling', () {
    test('keeps an https URL and removes trailing slashes', () {
      expect(
        WebdavService.normalizeUrl(
          'https://your-nas.your-tailnet.ts.net:8443///',
        ),
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
        WebdavService.normalizeUrl(
          'https://your-nas.your-tailnet.ts.net:8443/dav/',
        ),
        'https://your-nas.your-tailnet.ts.net:8443/dav',
      );
    });

    test('rejects insecure HTTP endpoints', () {
      expect(
        () => WebdavService.normalizeUrl('http://your-nas:8443/dav'),
        throwsA(isA<WebdavException>()),
      );
    });

    test('rejects credentials, queries and relative segments in the URL', () {
      for (final String value in <String>[
        'https://user:pass@your-nas:8443/dav',
        'https://your-nas:8443/dav?token=secret',
        'https://your-nas:8443/dav#fragment',
        'https://your-nas:8443/dav/../other',
        'https://your-nas:8443/dav/%2e%2e/other',
      ]) {
        expect(
          () => WebdavService.normalizeUrl(value),
          throwsA(isA<WebdavException>()),
          reason: value,
        );
      }
    });

    test('fileUrl appends encoded photo paths under /dav', () {
      final WebdavService service = WebdavService();
      expect(
        service.fileUrl('/uploads/photo one.jpg'),
        'https://your-nas.your-tailnet.ts.net:8443/dav/uploads/photo%20one.jpg',
      );
      expect(
        service.fileUrl('/file.jpg'),
        'https://your-nas.your-tailnet.ts.net:8443/dav/file.jpg',
      );
    });

    test('rejects remote paths that could escape the WebDAV root', () {
      final WebdavService service = WebdavService();
      expect(
        () => service.fileUrl('/uploads/../secret'),
        throwsA(isA<WebdavException>()),
      );
      expect(WebdavService.isSafeRemotePath('/uploads/photo.jpg'), isTrue);
      expect(WebdavService.isSafeRemotePath('/uploads/../secret'), isFalse);
    });

    test('allows literal percent-encoded characters in safe paths', () {
      expect(
        WebdavService.normalizeUrl('https://your-nas:8443/dav/100%25'),
        'https://your-nas:8443/dav/100%25',
      );
      expect(WebdavService.isSafeRemotePath('/uploads/100%25'), isTrue);
    });

    test('rejects double-encoded traversal in URLs and remote paths', () {
      for (final String value in <String>[
        'https://your-nas:8443/dav/%252e%252e/other',
        'https://your-nas:8443/dav/%252f..%252fother',
      ]) {
        expect(
          () => WebdavService.normalizeUrl(value),
          throwsA(isA<WebdavException>()),
          reason: value,
        );
      }
      expect(
        WebdavService.isSafeRemotePath('/uploads/%252e%252e/secret'),
        isFalse,
      );
      expect(
        WebdavService.isSafeRemotePath('/uploads/%252f..%252fsecret'),
        isFalse,
      );
    });

    test('rejects oversized downloads before opening the connection', () async {
      final WebdavService service = WebdavService();
      await expectLater(
        service.downloadFile(
          '/huge.bin',
          '/tmp/huge.bin',
          expectedSize: WebdavService.maxDownloadBytes + 1,
        ),
        throwsA(isA<WebdavException>()),
      );
    });
  });

  group('TutorialScreen', () {
    testWidgets('shows the five steps with an in-memory checklist', (
      WidgetTester tester,
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
      WidgetTester tester,
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

      final Finder scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Diagnostics'),
        300,
        scrollable: scrollable,
      );
      expect(find.text('Diagnostics'), findsOneWidget);
      expect(find.text('Test connection'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Support: contact your NAS administrator.'),
        300,
        scrollable: scrollable,
      );
      expect(
        find.text('Support: contact your NAS administrator.'),
        findsOneWidget,
      );
    });
  });

  group('Manifest-driven shell navigation', () {
    testWidgets('a member sees only member modules and cannot access admin', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, role: UserRole.user);

      final Finder navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);
      expect(
        find.descendant(of: navBar, matching: find.byType(NavigationDestination)),
        findsNWidgets(4),
      );
      for (final String label in <String>['Files', 'Photos', 'AI', 'Help']) {
        expect(_navLabel(label), findsOneWidget);
      }
      expect(_navLabel('Admin'), findsNothing);

      final AuthContext member = const AuthContext(
        role: UserRole.user,
        username: 'Member',
      );
      final ModuleDefinition adminModule = appModules.singleWhere(
        (ModuleDefinition module) => module.id == 'admin',
      );
      expect(RouteGuard.canAccess(member, adminModule), isFalse);
      expect(
        RouteGuard.denialMessage(member, adminModule),
        contains('Administrator'),
      );
    });

    testWidgets('an admin sees Administration and can open Help', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, role: UserRole.admin);

      final Finder navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);
      expect(
        find.descendant(of: navBar, matching: find.byType(NavigationDestination)),
        findsNWidgets(5),
      );
      expect(_navLabel('Admin'), findsOneWidget);

      final AuthContext admin = const AuthContext(
        role: UserRole.admin,
        username: 'Admin',
      );
      final ModuleDefinition adminModule = appModules.singleWhere(
        (ModuleDefinition module) => module.id == 'admin',
      );
      expect(RouteGuard.canAccess(admin, adminModule), isTrue);

      await tester.tap(_navLabel('Help'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 320));

      expect(
        tester.widget<NavigationBar>(navBar).selectedIndex,
        4,
      );
      expect(find.text('Frequently asked questions'), findsOneWidget);
    });
  });
}
