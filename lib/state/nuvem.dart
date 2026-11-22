import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ambiente.dart';
import '../core/drive.dart';
import '../core/erros.dart';
import '../data/repositorio.dart';
import 'store.dart';

/// Client ID "Aplicativo da Web" do Google Cloud, passado pela CI
/// (--dart-define). Vazio: o login não foi configurado nesta versão.
const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

/// Conta Google: o que a [Nuvem] precisa do login (os testes trocam).
abstract class Conta {
  /// E-mail da conta já conectada, sem perguntar nada ao usuário; ou null.
  Future<String?> retomar();

  /// Mostra o login e pede acesso ao Drive; devolve o e-mail.
  Future<String> entrar();

  /// Access token do Drive; [novo] descarta o anterior (expirou).
  Future<String> token(bool novo);
  Future<void> sair();
}

/// [Conta] de verdade, pelo google_sign_in.
class ContaGoogle implements Conta {
  static const escopo = 'https://www.googleapis.com/auth/drive.appdata';
  final _g = GoogleSignIn.instance;
  GoogleSignInAccount? _conta;
  String? _token;
  Future<void>? _iniciado;

  Future<void> _iniciar() =>
      _iniciado ??= _g.initialize(serverClientId: googleClientId);

  @override
  Future<String?> retomar() async {
    await _iniciar();
    _conta = await (_g.attemptLightweightAuthentication() ??
        Future<GoogleSignInAccount?>.value());
    return _conta?.email;
  }

  @override
  Future<String> entrar() async {
    try {
      await _iniciar();
      final c = await _g.authenticate(scopeHint: const [escopo]);
      _token = (await c.authorizationClient.authorizeScopes(const [escopo]))
          .accessToken;
      _conta = c;
      return c.email;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const ErroDoApp('login cancelado');
      }
      throw ErroDoApp(e.description ?? e.code.name);
    }
  }

  @override
  Future<String> token(bool novo) async {
    final c = _conta;
    if (c == null) throw const ErroDoApp('entre na conta Google');
    final velho = _token;
    if (novo && velho != null) {
      await c.authorizationClient.clearAuthorizationToken(accessToken: velho);
      _token = null;
    }
    if (_token case final t?) return t;
    // sem interação: em segundo plano não dá para mostrar o login
    final a = await c.authorizationClient.authorizationForScopes(const [escopo]);
    if (a == null) {
      throw const ErroDoApp('o acesso ao Drive expirou; entre de novo');
    }
    return _token = a.accessToken;
  }

  @override
  Future<void> sair() async {
    _conta = null;
    _token = null;
    await _g.signOut();
  }
}

/// Backup automático no Google Drive da própria pessoa. Opcional: sem login
/// o app funciona como antes.
class Nuvem extends ChangeNotifier {
  final Store _store;
  final Conta? _conta;
  final Drive? _drive;

  Nuvem(this._store, {Conta? conta, Drive? drive})
      : _conta = conta,
        _drive = drive ?? (conta == null ? null : Drive(conta.token));

  /// Com o login do Google, ou sem (build sem GOOGLE_CLIENT_ID).
  factory Nuvem.doApp(Store store) => Nuvem(store,
      conta: googleClientId.isEmpty ? null : ContaGoogle());

  bool get configurado => _conta != null;
  String? email;
  DateTime? ultimoBackup;
  bool ocupado = false;

  /// Falha do último backup automático (o manual avisa na hora).
  String? erro;

  /// Texto do último envio: sair do app sem mudar nada não envia de novo.
  String? _enviado;
  static const _chave = 'nuvem_ultimo_backup';

  /// Na abertura: volta à conta já conectada, sem pedir login.
  Future<void> retomar() async {
    try {
      final ms = (await SharedPreferences.getInstance()).getInt(_chave);
      if (ms != null) ultimoBackup = DateTime.fromMillisecondsSinceEpoch(ms);
      email = await _conta?.retomar();
    } catch (_) {
      // sem conta conectada: o botão "Entrar com Google" resolve
    }
    notifyListeners();
  }

  Future<void> entrar() async {
    final c = _conta;
    if (c == null) return;
    email = await doAmbiente(c.entrar, 'não foi possível entrar');
    erro = null;
    notifyListeners();
  }

  Future<void> sair() async {
    await _conta?.sair();
    email = null;
    _enviado = null;
    notifyListeners();
  }

  /// Envia os dados agora (botão "Fazer backup agora").
  Future<void> backupAgora() => _ocupado(() async {
        final texto = await _store.exportar();
        ultimoBackup =
            await doAmbiente(() => _drive!.enviar(texto), 'backup falhou');
        _enviado = texto;
        erro = null;
        (await SharedPreferences.getInstance())
            .setInt(_chave, ultimoBackup!.millisecondsSinceEpoch);
      });

  /// App indo para segundo plano: envia se estiver na conta e algo mudou.
  /// Falha não interrompe nada: fica em [erro] e tenta na próxima vez.
  // ponytail: só ao sair do app; envio periódico (workmanager) se for preciso
  Future<void> aoPausar() async {
    if (email == null || ocupado) return;
    try {
      if (await _store.exportar() == _enviado) return;
      await backupAgora();
    } catch (e) {
      erro = mensagem(e);
      notifyListeners();
    }
  }

  /// Backup do Drive já validado (null se ainda não há); quem substitui os
  /// dados é a tela, depois de confirmar, com [Store.importar].
  Future<({Dados dados, DateTime quando})?> baixar() async {
    final b = await doAmbiente(() => _drive!.baixar(), 'não foi possível baixar');
    if (b == null) return null;
    try {
      return (dados: Dados.deTexto(b.texto), quando: b.quando);
    } on DadosDeVersaoMaisNova {
      throw const ErroDoApp('o backup do Drive é de uma versão mais nova do '
          'app; atualize o app para restaurá-lo');
    } on FormatException catch (e) {
      throw ErroDoApp('backup do Drive inválido (${e.message})');
    }
  }

  Future<void> _ocupado(Future<void> Function() f) async {
    ocupado = true;
    notifyListeners();
    try {
      await f();
    } finally {
      ocupado = false;
      notifyListeners();
    }
  }
}
