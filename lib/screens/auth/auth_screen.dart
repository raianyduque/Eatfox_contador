// autenticaçao da conta, criaçao, login e registrar com email ou google.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController userController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void toggleAuthMode() {
    setState(() {
      isLogin = !isLogin;
      passwordController.clear();
      confirmPasswordController.clear();
    });
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _traduzirErroAuth(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Este e-mail já está cadastrado.';
      case 'invalid-email': return 'O formato do e-mail é inválido.';
      case 'weak-password': return 'A senha é muito fraca.';
      case 'user-not-found': return 'Usuário não encontrado. Verifique o e-mail.';
      case 'wrong-password': return 'A senha está incorreta.';
      case 'invalid-credential': return 'Credenciais inválidas. Verifique seu e-mail e senha.';
      case 'user-disabled': return 'Esta conta foi desativada.';
      case 'operation-not-allowed': return 'Operação não permitida.';
      case 'too-many-requests': return 'Muitas tentativas. Tente novamente mais tarde.';
      default: return 'Erro ao autenticar. Tente novamente ($code).';
    }
  }

  bool _validarSenha(String senha) {
    if (senha.length < 8) return false;
    bool temLetra = senha.contains(RegExp(r'[a-zA-Z]'));
    bool temNumero = senha.contains(RegExp(r'[0-9]'));
    return temLetra && temNumero;
  }

  Future<void> _salvarCredenciaisNoBanco(String uid, String email, String senha) async {
    await _firestore.collection('usuarios').doc(uid).set({
      'email': email,
      'senha_salva': senha, 
    }, SetOptions(merge: true));
  }

  Future<void> _verificarRedirecionamento(User user) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (mounted) {
        if (doc.exists && doc.data() != null && doc.data()!.containsKey('objetivo')) {
          String mascot = doc.data()!['nomeMascote'] ?? 'Bixinho';
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(mascotName: mascot)));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingScreen()));
        }
      }
    } catch (e) {
      _mostrarErro('Erro no banco de dados: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autenticarEmailSenha() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostrarErro('Preencha todos os campos obrigatórios.');
      return;
    }

    if (!isLogin) {
      if (!_validarSenha(password)) {
        _mostrarErro('A senha deve ter no mínimo 8 caracteres, contendo letras e números.');
        return;
      }
      if (password != confirmPasswordController.text) {
        _mostrarErro('As senhas digitadas não coincidem.');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      UserCredential cred;
      if (isLogin) {
        cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        if (userController.text.isNotEmpty) await cred.user?.updateDisplayName(userController.text.trim());
        await _salvarCredenciaisNoBanco(cred.user!.uid, email, password);
      }
      await _verificarRedirecionamento(cred.user!);
    } on FirebaseAuthException catch (e) {
      _mostrarErro(_traduzirErroAuth(e.code));
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      _mostrarErro('Erro inesperado: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _autenticarComGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      UserCredential cred = await _auth.signInWithCredential(credential);
      String emailUsuario = cred.user!.email ?? googleUser.email;

      final doc = await _firestore.collection('usuarios').doc(cred.user!.uid).get();

      if (!doc.exists) {
        await _firestore.collection('usuarios').doc(cred.user!.uid).set({
          'email': emailUsuario,
        }, SetOptions(merge: true));
      }

      await _verificarRedirecionamento(cred.user!);
      
    } on FirebaseAuthException catch (e) {
      _mostrarErro(_traduzirErroAuth(e.code));
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      _mostrarErro('Erro inesperado do Google: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirFormularioEmail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isLogin ? 'Entrar com E-mail' : 'Criar Conta com E-mail',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'LilitaOne', fontSize: 26, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 20),
                  if (!isLogin) ...[
                    _buildTextField(controller: userController, hint: 'Nome de usuário'),
                    const SizedBox(height: 12),
                  ],
                  _buildTextField(controller: emailController, hint: 'E-mail', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  if (!isLogin)
                    const Padding(
                      padding: EdgeInsets.only(left: 12.0, bottom: 6.0),
                      child: Text('Mínimo de 8 caracteres, contendo letras e números.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  _buildTextField(controller: passwordController, hint: 'Senha', isPassword: true),
                  const SizedBox(height: 12),
                  if (!isLogin) ...[
                    _buildTextField(controller: confirmPasswordController, hint: 'Confirmar Senha', isPassword: true),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: _isLoading ? null : () {
                      Navigator.pop(context);
                      _autenticarEmailSenha();
                    },
                    child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                      : Text(isLogin ? 'Entrar' : 'Registrar', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        toggleAuthMode();
                      });
                    },
                    child: Text(
                      isLogin ? 'Não tem uma conta? Registre-se' : 'Já tem uma conta? Entre',
                      style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey.shade600),
              onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible)
            ) 
          : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/fundo.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.primaryOrange),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Alcance suas metas de peso',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'LilitaOne',
                      fontSize: 40,
                      color: Color.fromARGB(255, 36, 36, 36),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.textDark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 2,
                    ),
                    icon: Image.network(
                      'https://img.icons8.com/color/48/000000/google-logo.png',
                      height: 24, width: 24,
                    ),
                    label: const Text('Continuar com Google', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: _isLoading ? null : _autenticarComGoogle,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.email_rounded, color: Colors.white, size: 24),
                    label: const Text('Continuar com e-mail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: _isLoading ? null : _abrirFormularioEmail,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ao continuar, você aceita nossos Termos de Uso e Política de Privacidade.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 36, 36, 36)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}