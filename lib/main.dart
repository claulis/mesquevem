import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/atualizacao.dart';
import 'core/aviso_versao.dart';
import 'data/repositorio_prefs.dart';
import 'state/atualizador.dart';
import 'state/fundo.dart';
import 'state/store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // trocar o armazenamento (SQLite, nuvem) = outra implementação de Repositorio aqui
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => Store(RepositorioPrefs())),
    ChangeNotifierProvider(create: (_) => Fundo()..carregar()),
    // não preguiçoso: download interrompido continua assim que o app abre
    ChangeNotifierProvider(
        lazy: false, create: (_) => Atualizador()..retomarSalvo().ignore()),
  ], child: const App()));
  // build de desenvolvimento não tem versão para comparar
  if (buildAtual > 0) _avisosDeVersao();
}

void _abrirAtualizar() => App.navegador.currentState?.pushNamed('/atualizar');

/// Notificação (toque abre "Atualizar"), verificação periódica em segundo
/// plano e uma verificação agora, que avisa com um SnackBar.
Future<void> _avisosDeVersao() async {
  try {
    await iniciarNotificacoes(aoTocar: _abrirAtualizar);
    final abertura = await notificacoes.getNotificationAppLaunchDetails();
    if (abertura?.didNotificationLaunchApp ?? false) _abrirAtualizar();
    await pedirPermissaoDeNotificar();
    await agendarVerificacao();
    final r = await ultimaRelease();
    if (temNova(r)) {
      App.mensagens.currentState?.showSnackBar(SnackBar(
        content: Text('Nova versão ${r.tag} disponível'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(label: 'Atualizar', onPressed: _abrirAtualizar),
      ));
    }
  } catch (_) {
    // sem rede ou sem permissão: só não avisa; Config → Atualizar continua lá
  }
}
