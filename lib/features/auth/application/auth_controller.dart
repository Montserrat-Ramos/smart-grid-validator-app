import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/entities/auth_user.dart';
import '../domain/ports/auth_repository.dart';

enum AuthStatus { checking, authenticated, unauthenticated }
class AuthState {
  const AuthState({required this.status,this.user,this.isSubmitting=false,this.errorMessage});
  const AuthState.checking():this(status:AuthStatus.checking);
  final AuthStatus status; final AuthUser? user; final bool isSubmitting; final String? errorMessage;
  AuthState copyWith({AuthStatus? status,AuthUser? user,bool? isSubmitting,String? errorMessage,bool clearError=false})=>AuthState(status:status??this.status,user:user??this.user,isSubmitting:isSubmitting??this.isSubmitting,errorMessage:clearError?null:errorMessage??this.errorMessage);
}
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository,this._apiClient):super(const AuthState.checking()){_apiClient.onUnauthorized=_refreshForApiClient;_restore();}
  final AuthRepository _repository; final ApiClient _apiClient;
  Future<void> _restore() async {final s=await _repository.restore();state=s==null?const AuthState(status:AuthStatus.unauthenticated):AuthState(status:AuthStatus.authenticated,user:s.user);}
  Future<bool> _refreshForApiClient() async {try{final s=await _repository.refresh();state=AuthState(status:AuthStatus.authenticated,user:s.user);return true;}catch(_){await _repository.clearSession();state=const AuthState(status:AuthStatus.unauthenticated);return false;}}
  Future<bool> login(String email,String password)=>_authenticate(()=>_repository.login(email,password));
  Future<bool> register(String name,String email,String password)=>_authenticate(()=>_repository.register(name,email,password));
  Future<bool> guest()=>_authenticate(()=>_repository.guest());
  Future<bool> _authenticate(Future<dynamic> Function() action) async {state=state.copyWith(isSubmitting:true,clearError:true);try{final s=await action();state=AuthState(status:AuthStatus.authenticated,user:s.user);return true;}on ApiException catch(e){state=AuthState(status:AuthStatus.unauthenticated,errorMessage:e.message);return false;}catch(_){state=const AuthState(status:AuthStatus.unauthenticated,errorMessage:'No fue posible completar el acceso.');return false;}}
  Future<void> forgotPassword(String email)=>_repository.forgotPassword(email);
  Future<void> changePassword(String current,String next) async {await _repository.changePassword(current,next);await logout();}
  Future<void> revokeAllSessions()=>_repository.revokeAllSessions();
  Future<void> updateProfile(String name,String email) async {final user=await _repository.updateProfile(name,email);state=state.copyWith(user:user);}
  Future<void> logout() async {state=state.copyWith(isSubmitting:true,clearError:true);await _repository.logout();state=const AuthState(status:AuthStatus.unauthenticated);}
  void clearError()=>state=state.copyWith(clearError:true);
}
