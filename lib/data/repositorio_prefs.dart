import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'repositorio.dart';

class RepositorioPrefs implements Repositorio {
  @override
  Future<Dados> carregar() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('dados');
    final bruto = s ?? p.getString('compras');
    if (bruto == null) return Dados.padrao();

    final int versao;
    final Dados dados;
    try {
      final Map<String, dynamic> j = s != null
          ? jsonDecode(s)
          : {'versao': 0, 'compras': jsonDecode(bruto)};
      versao = j['versao'] as int? ?? 1;
      dados = Dados.fromJson(j);
    } catch (e) {
      await _guardarCopia(p, bruto);
      throw DadosCorrompidos(bruto, e);
    }
    if (versao < versaoAtual) await salvar(dados);
    return dados;
  }

  static const prefixoCopia = 'dados_corrompidos_';

  /// Uma cópia por conteúdo distinto, para não duplicar a cada tentativa.
  static Future<void> _guardarCopia(SharedPreferences p, String bruto) async {
    final jaGuardado = p
        .getKeys()
        .where((k) => k.startsWith(prefixoCopia))
        .any((k) => p.getString(k) == bruto);
    if (!jaGuardado) {
      await p.setString(
          '$prefixoCopia${DateTime.now().millisecondsSinceEpoch}', bruto);
    }
  }

  @override
  Future<void> salvar(Dados d) async => (await SharedPreferences.getInstance())
      .setString('dados', jsonEncode(d));
}
