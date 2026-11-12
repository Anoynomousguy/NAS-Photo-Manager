import 'package:flutter/widgets.dart';

enum UserRole { user, admin }

extension UserRoleMetadata on UserRole {
  String get label => this == UserRole.admin ? 'Administrator' : 'Member';

  int get rank => this == UserRole.admin ? 2 : 1;

  bool canAccess(UserRole requiredRole) => rank >= requiredRole.rank;
}

@immutable
class AuthContext {
  const AuthContext({
    required this.role,
    required this.username,
    this.isMock = true,
  });

  /// The mobile app uses a mock identity until a real session provider is
  /// wired in. The default is deliberately the least-privileged role.
  factory AuthContext.fromEnvironment() {
    const String roleName = String.fromEnvironment(
      'APP_ROLE',
      defaultValue: 'user',
    );
    const String username = String.fromEnvironment(
      'APP_USER',
      defaultValue: 'Member',
    );
    return AuthContext(
      role: roleName == 'admin' ? UserRole.admin : UserRole.user,
      username: username,
    );
  }

  final UserRole role;
  final String username;
  final bool isMock;

  bool canAccess(UserRole requiredRole) => role.canAccess(requiredRole);
}

/// The Flutter equivalent of the web Auth Context. Modules read this rather
/// than passing role booleans around, so the shell and Help always agree.
class AuthScope extends InheritedWidget {
  const AuthScope({
    super.key,
    required this.auth,
    required super.child,
  });

  final AuthContext auth;

  static AuthContext of(BuildContext context) {
    final AuthScope? scope = context
        .dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope is missing above this widget.');
    return scope!.auth;
  }

  static AuthContext? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AuthScope>()?.auth;
  }

  @override
  bool updateShouldNotify(AuthScope oldWidget) {
    return auth.role != oldWidget.auth.role ||
        auth.username != oldWidget.auth.username ||
        auth.isMock != oldWidget.auth.isMock;
  }
}
