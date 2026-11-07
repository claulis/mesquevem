import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/format.dart';

/// "Ocultar valores", como nos apps de banco: para prints sem mostrar quanto
/// se gasta. Fica no aparelho (não vai no backup) e continua ao reabrir.
class Privacidade extends ChangeNotifier {
  static const _chave = 'ocultar_valores';

  bool get ocultos => valoresOcultos;

  Future<void> carregar() async {
    try {
      valoresOcultos =
          (await SharedPreferences.getInstance()).getBool(_chave) ?? false;
      notifyListeners();
    } on Exception {
      // sem preferência: valores visíveis
    }
  }

  Future<void> alternar() async {
    valoresOcultos = !valoresOcultos;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance())
          .setBool(_chave, valoresOcultos);
    } on Exception {
      // não gravou: vale até fechar o app
    }
  }
}
