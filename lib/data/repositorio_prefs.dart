import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ambiente.dart';
import 'repositorio.dart';

class RepositorioPrefs implements Repositorio {
  // O setString põe o valor no cache em memória antes de gravar; se a gravação
  // falha, o cache fica com algo que não está no disco até um reload().
  static bool _cacheDesatualizado = false;

  @override
  Future<Dados> carregar() async {
    final p = await SharedPreferences.getInstance();
    if (_cacheDesatualizado) {
      await p.reload();
      _cacheDesatualizado = false;
    }
    // get + texto: valor de outro tipo (ex.: lista) não pode lançar TypeError
    // aqui fora; vira JSON (sem perder nada, para a cópia ser fiel), não é um
    // objeto e segue como corrompido
    final s = _texto(p.get('dados'));
    final bruto = s ?? _texto(p.get('compras'));
    if (bruto == null) return Dados.padrao();

    final int versao;
    final Dados dados;
    try {
      final j = s != null
          ? jsonDecode(s)
          : {'versao': 0, 'compras': jsonDecode(bruto)};
      if (j is! Map<String, dynamic>) {
        throw const FormatException('os dados salvos não são um objeto JSON');
      }
      versao = Dados.versaoDe(j);
      dados = Dados.fromJson(j);
    } on DadosDeVersaoMaisNova {
      rethrow; // dados válidos de um app mais novo: nada de cópia nem "recomeçar"
    } catch (e) {
      // guardar uma cópia não custa nada e protege em qualquer caso
      final copiaGuardada = await _guardarCopia(p, bruto);
      // só formato inválido é corrupção; outro Error é defeito do app, sobe
      // como está (com o stack original) e não pode apagar dados talvez bons
      if (e is FormatException) {
        throw DadosCorrompidos(bruto, e, copiaGuardada: copiaGuardada);
      }
      rethrow;
    }
    if (versao < versaoAtual) {
      try {
        await salvar(dados);
      } on FalhaAoSalvar {
        // a migração é refeita na próxima abertura (com os mesmos ids); não
        // impede de usar o app. Outro erro é defeito e segue adiante.
      }
    }
    return dados;
  }

  static String? _texto(Object? v) => switch (v) {
        null => null,
        String s => s,
        // os tipos do SharedPreferences (lista de textos, número, bool) têm
        // representação JSON exata
        _ => jsonEncode(v),
      };

  static const prefixoCopia = 'dados_corrompidos_';

  /// Uma cópia por conteúdo distinto, para não duplicar a cada tentativa.
  /// Devolve false se não conseguiu gravá-la. Melhor esforço: nenhum erro
  /// daqui pode encobrir o erro original da leitura.
  static Future<bool> _guardarCopia(SharedPreferences p, String bruto) async {
    try {
      final jaGuardado = p
          .getKeys()
          .where((k) => k.startsWith(prefixoCopia))
          .any((k) => p.get(k) == bruto); // get: chave pode não ser String
      if (!jaGuardado) {
        await _gravar(() => p.setString(
            '$prefixoCopia${DateTime.now().millisecondsSinceEpoch}', bruto));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> salvar(Dados d) async {
    // fora do _gravar: erro aqui é dos dados (defeito), não do armazenamento
    final texto = jsonEncode(d);
    await _gravar(() async =>
        (await SharedPreferences.getInstance()).setString('dados', texto));
  }

  /// Converte falhas do armazenamento (false ou Exception) em [FalhaAoSalvar].
  /// Errors (TypeError etc.) são defeitos e passam como estão.
  static Future<void> _gravar(Future<bool> Function() gravar) async {
    const motivo = 'o armazenamento recusou a gravação';
    var ok = false;
    try {
      ok = await doAmbiente(gravar, motivo, criar: FalhaAoSalvar.new);
    } finally {
      if (!ok) _cacheDesatualizado = true;
    }
    if (!ok) throw const FalhaAoSalvar(motivo);
  }
}
