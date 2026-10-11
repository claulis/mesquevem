import 'dart:convert';
import 'compra.dart';

/// Versão do formato JSON (armazenamento interno e arquivo de backup).
/// Mudou o formato? Suba este número e acrescente um `if (v < N)` em [Dados._migrar].
const versaoAtual = 2;

class Dados {
  final List<Compra> compras;
  final List<String> catCompra, catEvento;
  Dados(
      {required this.compras, required this.catCompra, required this.catEvento});

  factory Dados.padrao() => Dados(
        compras: [],
        catCompra: ['Alimentação', 'Transporte', 'Lazer', 'Outros'],
        catEvento: ['Dia a dia', 'Aniversário', 'Natal', 'Viagem'],
      );

  Map<String, dynamic> toJson() => {
        'versao': versaoAtual,
        'compras': compras,
        'catCompra': catCompra,
        'catEvento': catEvento,
      };

  /// Aceita qualquer versão até [versaoAtual]; lança se o JSON for inválido.
  factory Dados.fromJson(Map<String, dynamic> j) {
    final v = j['versao'] as int? ?? 1;
    if (v > versaoAtual) {
      throw const FormatException(
          'dados de uma versão mais nova do app; atualize o app');
    }
    _migrar(j, v);
    return Dados(
      compras: [for (final c in j['compras']) Compra.fromJson(c)],
      catCompra: List<String>.from(j['catCompra']),
      catEvento: List<String>.from(j['catEvento']),
    );
  }

  /// Lê um arquivo de backup. Lança se não for um backup válido.
  factory Dados.deTexto(String texto) {
    final j = jsonDecode(texto);
    if (j is! Map<String, dynamic>) {
      throw const FormatException('não é um backup do app Compras');
    }
    return Dados.fromJson(j);
  }

  /// Leva o JSON de qualquer versão antiga até [versaoAtual], um passo por vez.
  static void _migrar(Map<String, dynamic> j, int v) {
    if (v < 1) {
      // v0: só a lista de compras, na chave 'compras'
      final p = Dados.padrao();
      j['catCompra'] = p.catCompra;
      j['catEvento'] = p.catEvento;
    }
    if (v < 2) {
      for (final c in j['compras']) {
        c['id'] ??= novoId();
      }
    }
  }
}

/// Lançada por [Repositorio.carregar] quando há dados salvos mas eles não podem
/// ser lidos. A implementação deve guardar uma cópia de [bruto] antes de lançar,
/// para que "começar do zero" nunca perca o original.
class DadosCorrompidos implements Exception {
  final String bruto;
  final Object causa;
  const DadosCorrompidos(this.bruto, this.causa);
  @override
  String toString() => 'Dados corrompidos: $causa';
}

/// Onde os dados moram. Para trocar SharedPreferences por SQLite ou nuvem,
/// implemente esta interface e passe a nova classe ao Store em main.dart.
abstract interface class Repositorio {
  Future<Dados> carregar();
  Future<void> salvar(Dados dados);
}
