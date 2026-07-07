import '../../../core/network/api_client.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/auth_user.dart';
import '../domain/ports/auth_repository.dart';
import 'auth_local_storage.dart';

class AuthApiRepository implements AuthRepository {
  AuthApiRepository(this._apiClient, this._storage);
  final ApiClient _apiClient;
  final AuthLocalStorage _storage;
  AuthSession? _session;

  @override
  Future<AuthSession> login(String email, String password) async => _persist(AuthSession.fromJson(await _apiClient.postJson('/auth/login', {'email': email.trim(), 'password': password}, authenticated: false, retryOnUnauthorized: false) as Map<String,dynamic>));
  @override
  Future<AuthSession> register(String name, String email, String password) async => _persist(AuthSession.fromJson(await _apiClient.postJson('/auth/register', {'name': name.trim(), 'email': email.trim(), 'password': password}, authenticated: false, retryOnUnauthorized: false) as Map<String,dynamic>));
  @override
  Future<AuthSession> guest([String displayName = 'Invitado']) async => _persist(AuthSession.fromJson(await _apiClient.postJson('/auth/guest', {'displayName': displayName}, authenticated: false, retryOnUnauthorized: false) as Map<String,dynamic>));

  @override
  Future<AuthSession?> restore() async {
    final stored = await _storage.read();
    if (stored == null) return null;
    _session = stored; _apiClient.setAccessToken(stored.accessToken);
    try {
      final payload = await _apiClient.getJson('/auth/me') as Map<String,dynamic>;
      return _persist(stored.copyWith(user: AuthUser.fromJson(payload)));
    } on ApiException {
      if (stored.refreshToken != null) {
        try { return await refresh(); } catch (_) {}
      }
      await clearSession(); return null;
    }
  }

  @override
  Future<AuthSession> refresh() async {
    final current = _session ?? await _storage.read();
    if (current?.refreshToken == null) throw const ApiException('La sesión no puede renovarse.');
    final payload = await _apiClient.postJson('/auth/refresh', {'refreshToken': current!.refreshToken}, authenticated: false, retryOnUnauthorized: false) as Map<String,dynamic>;
    return _persist(AuthSession.fromJson(payload));
  }

  @override
  Future<void> logout() async {
    final current = _session ?? await _storage.read();
    if (current?.refreshToken != null) {
      try { await _apiClient.postJson('/auth/logout', {'refreshToken': current!.refreshToken}, retryOnUnauthorized: false); } catch (_) {}
    }
    await clearSession();
  }

  @override
  Future<void> forgotPassword(String email) async { await _apiClient.postJson('/auth/forgot-password', {'email': email}, authenticated: false, retryOnUnauthorized: false); }
  @override
  Future<void> changePassword(String currentPassword, String newPassword) async { await _apiClient.postJson('/auth/change-password', {'currentPassword': currentPassword, 'newPassword': newPassword}); }
  @override
  Future<void> revokeAllSessions() async { await _apiClient.postJson('/auth/sessions/revoke-all', const {}); }
  @override
  Future<AuthUser> updateProfile(String name, String email) async {
    final payload = await _apiClient.putJson('/auth/profile', {'name': name, 'email': email}) as Map<String,dynamic>;
    final updated = AuthUser.fromJson(payload);
    final current = _session ?? await _storage.read();
    if (current != null) await _persist(current.copyWith(user: updated));
    return updated;
  }
  @override
  Future<void> clearSession() async { _session = null; _apiClient.setAccessToken(null); await _storage.clear(); }
  Future<AuthSession> _persist(AuthSession session) async { _session=session; _apiClient.setAccessToken(session.accessToken); await _storage.save(session); return session; }
}
