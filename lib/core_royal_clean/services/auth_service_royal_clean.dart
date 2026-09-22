import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthServiceRoyalClean {
  AuthServiceRoyalClean._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static Future<AuthAdminResult> signInAdmin({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        await _auth.signOut();
        return const AuthAdminResult(
          success: false,
          message: 'Não foi possível identificar o usuário autenticado.',
        );
      }

      final uid = user.uid;
      final userEmail = (user.email ?? '').trim().toLowerCase();

      final adminDoc = await _firestore
          .collection('admin')
          .doc(uid)
          .get(const GetOptions(source: Source.server));

      if (!adminDoc.exists) {
        await _auth.signOut();
        return const AuthAdminResult(
          success: false,
          message: 'Este usuário não possui permissão administrativa.',
        );
      }

      final data = adminDoc.data();
      if (data == null) {
        await _auth.signOut();
        return const AuthAdminResult(
          success: false,
          message: 'Os dados administrativos não puderam ser carregados.',
        );
      }

      final bool isAdmin = data['eAdministrador'] == true;
      final bool isActive = data['ativo'] == true;
      final String adminEmail = (data['email']?.toString() ?? '')
          .trim()
          .toLowerCase();

      if (!isAdmin) {
        await _auth.signOut();
        return const AuthAdminResult(
          success: false,
          message: 'Este usuário não possui permissão administrativa.',
        );
      }

      if (!isActive) {
        await _auth.signOut();
        return const AuthAdminResult(
          success: false,
          message: 'Esta conta administrativa está inativa.',
        );
      }

      if (adminEmail != userEmail) {
        await _auth.signOut();
        return const AuthAdminResult(
          success: false,
          message: 'O e-mail autenticado não corresponde ao admin cadastrado.',
        );
      }

      return const AuthAdminResult(
        success: true,
        message: 'Login administrativo realizado com sucesso.',
      );
    } on FirebaseAuthException catch (e) {
      await _clearFailedSession();
      return AuthAdminResult(success: false, message: _mapFirebaseAuthError(e));
    } catch (e) {
      await _clearFailedSession();
      return AuthAdminResult(
        success: false,
        message: 'Erro inesperado ao entrar no painel administrativo: $e',
      );
    }
  }

  static Future<void> _clearFailedSession() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Route guards continue to deny access if authorization cannot be checked.
    }
  }

  static String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'O e-mail informado é inválido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
        return 'Nenhum usuário encontrado com este e-mail.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente em instantes.';
      case 'network-request-failed':
        return 'Falha de conexão. Verifique sua internet.';
      default:
        return 'Não foi possível realizar o login.';
    }
  }
}

class AuthAdminResult {
  final bool success;
  final String message;

  const AuthAdminResult({required this.success, required this.message});
}
