import 'package:flutter/services.dart' show PlatformException;
import 'erros.dart';

/// Texto de um erro para o usuário, sem prefixos técnicos como
/// "FormatException: ". Toda tela que mostra um erro passa por aqui.
String mensagem(Object e) => switch (e) {
      ErroDoApp(:final motivo) => motivo,
      FormatException(:final message) => message,
      PlatformException(:final message, :final code) => message ?? code,
      _ => '$e',
    };

/// Roda [f], que depende do ambiente (disco, seletor de arquivos, plugin).
/// [Exception] dele é falha do ambiente, não do app: vira [criar] com o
/// [motivo] e o detalhe legível. Errors (defeitos) passam como estão.
Future<T> doAmbiente<T>(Future<T> Function() f, String motivo,
    {ErroDoApp Function(String motivo) criar = ErroDoApp.new}) async {
  try {
    return await f();
  } on Exception catch (e) {
    throw criar('$motivo (${mensagem(e)})');
  }
}
