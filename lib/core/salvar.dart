import 'package:flutter/material.dart';
import 'ambiente.dart';
import 'erros.dart';

/// Roda [acao] e, se ela falhar, avisa o usuário (numa alteração do Store, a
/// tela continua com o estado anterior). Devolve true se deu certo.
///
/// Erro que não é [ErroDoApp] é defeito: além do aviso, vai para o
/// [FlutterError.reportError], para não sumir como se fosse falha comum.
Future<bool> avisandoFalha(BuildContext context, Future<void> Function() acao,
    {String falha = 'Não foi possível salvar'}) async {
  final msg = ScaffoldMessenger.of(context);
  try {
    await acao();
    return true;
  } catch (e, st) {
    if (e is! ErroDoApp) reportarDefeito(e, st, falha);
    msg.showSnackBar(SnackBar(content: Text('$falha: ${mensagem(e)}')));
    return false;
  }
}

/// Erro que não era previsto é defeito do app: vai para o
/// [FlutterError.reportError], para não sumir como se fosse falha comum.
void reportarDefeito(Object e, StackTrace st, String contexto) =>
    FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'compras',
        context: ErrorSummary(contexto)));
