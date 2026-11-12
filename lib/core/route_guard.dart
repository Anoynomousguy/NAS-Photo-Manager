import 'auth_context.dart';
import 'module.dart';

abstract final class RouteGuard {
  static bool canAccess(AuthContext auth, ModuleDefinition module) {
    return auth.canAccess(module.requiredRole);
  }

  static String denialMessage(AuthContext auth, ModuleDefinition module) {
    return '${module.title} requires the ${module.requiredRole.label} role. '
        'You are signed in as ${auth.role.label.toLowerCase()}.';
  }
}
