import '../entities/auth_session.dart';
import '../entities/auth_user.dart';

abstract class AuthRepository {
  Future<AuthSession> login(String email, String password);
  Future<AuthSession> register(String name, String email, String password);
  Future<AuthSession> guest([String displayName = 'Invitado']);
  Future<AuthSession?> restore();
  Future<AuthSession> refresh();
  Future<void> logout();
  Future<void> clearSession();
  Future<void> forgotPassword(String email);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> revokeAllSessions();
  Future<AuthUser> updateProfile(String name, String email);
}
