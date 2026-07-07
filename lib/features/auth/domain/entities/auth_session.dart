import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: (json['accessToken'] ?? json['access_token']).toString(),
        refreshToken: (json['refreshToken'] ?? json['refresh_token'])?.toString(),
        expiresIn: json['expiresIn'] as int? ?? json['expires_in'] as int? ?? 900,
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresIn': expiresIn,
        'user': user.toJson(),
      };

  AuthSession copyWith({AuthUser? user}) => AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
        user: user ?? this.user,
      );
}
