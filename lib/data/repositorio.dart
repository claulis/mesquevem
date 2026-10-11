import 'dart:convert';
import '../core/erros.dart';
import 'compra.dart';

/// Versão do formato JSON (armazenamento interno e arquivo de backup).
/// Mudou o formato? Suba este número e acrescente um `if (v < N)` em [Dados._migrar].
const versaoAtual = 2;

class Dados {
  final List<Compra> compras;
  final List<String> catCompra, catEvento;
  Dados(
      {required this.compras,
      required this.catCompra,
      required this.catEvento});

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

  // acima disso não é versão de verdade, é dado corrompido (ex.: 1e300)
  static const _versaoLimite = 1000000;

  /// Versão do formato de [j]; sem o campo, é a v1 (anterior ao versionamento).
  static int versaoDe(Map<String, dynamic> j) => switch (j['versao']) {
        null => 1,
        int v when v >= 0 && v <= _versaoLimite => v,
        // 2.0 de ferramentas que gravam todo número como decimal
        double v when v >= 0 && v <= _versaoLimite && v == v.truncate() =>
          v.toInt(),
        final v => throw FormatException('campo "versao" inválido: $v'),
      };

  /// Aceita qualquer versão até [versaoAtual]; lança [FormatException] se o
  /// JSON for inválido ([DadosDeVersaoMaisNova] se for de um app mais novo).
  /// Não altera [j].
  factory Dados.fromJson(Map<String, dynamic> j) {
    final v = versaoDe(j);
    if (v > versaoAtual) throw DadosDeVersaoMaisNova(v);
    try {
      j = _migrar(j, v);
      return Dados(
        compras: _semIdsRepetidos(
            [for (final c in j['compras']) Compra.fromJson(c)]),
        catCompra: _categoriasValidas(j['catCompra']),
        catEvento: _categoriasValidas(j['catEvento']),
      );
    } on TypeError {
      // campo ausente ou de tipo errado. Só TypeError: outros Errors são
      // defeitos do app e não podem passar por dados inválidos
      throw const FormatException(
          'estrutura de dados inválida (campo ausente ou de tipo errado)');
    }
  }

  /// Lê um arquivo de backup. Lança se não for um backup válido.
  factory Dados.deTexto(String texto) {
    // editores do Windows podem gravar BOM, que o jsonDecode não aceita
    if (texto.startsWith('\uFEFF')) texto = texto.substring(1);
    final j = jsonDecode(texto);
    if (j is! Map<String, dynamic>) {
      throw const FormatException('não é um backup do app Compras');
    }
    return Dados.fromJson(j);
  }

  /// O Store supõe nomes não vazios e únicos; backup editado à mão pode ter
  /// repetidos ou vazios, que são descartados (mantendo a ordem).
  static List<String> _categoriasValidas(Object? lista) =>
      List<String>.from(lista as List)
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();

  /// Cópia rasa: listas novas, compras (imutáveis) compartilhadas. Campo novo
  /// em [Dados] entra aqui, junto do construtor.
  Dados copia() => Dados(
      compras: List.of(compras),
      catCompra: List.of(catCompra),
      catEvento: List.of(catEvento));

  /// Backup editado à mão pode repetir ids; o Store localiza compras pelo id.
  /// A repetição ganha sufixo determinístico ("x-2"), igual a cada leitura.
  static List<Compra> _semIdsRepetidos(List<Compra> compras) {
    final usados = <String>{};
    for (var i = 0; i < compras.length; i++) {
      final c = compras[i];
      if (usados.add(c.id)) continue;
      var n = 2;
      while (!usados.add('${c.id}-$n')) {
        n++;
      }
      compras[i] = c.copiaCom(id: '${c.id}-$n');
    }
    return compras;
  }

  /// Leva o JSON de qualquer versão antiga até [versaoAtual], um passo por vez.
  /// Devolve um mapa novo; o original não é alterado.
  static Map<String, dynamic> _migrar(Map<String, dynamic> original, int v) {
    final j = Map<String, dynamic>.of(original);
    if (v < 1) {
      // v0: só a lista de compras, na chave 'compras'
      final p = Dados.padrao();
      j['catCompra'] = p.catCompra;
      j['catEvento'] = p.catEvento;
    }
    if (v < 2) {
      // id determinístico (posição na lista): se a gravação da migração
      // falhar, a próxima abertura gera os mesmos ids. Colisão com id já
      // existente é resolvida em _semIdsRepetidos.
      j['compras'] = [
        for (final (i, c) in (j['compras'] as List).indexed)
          {...c as Map<String, dynamic>, 'id': c['id'] ?? 'v1-$i'}
      ];
    }
    return j;
  }
}

/// O JSON foi gravado por um app mais novo que este. Os dados não estão
/// corrompidos: não devem ser copiados nem apagados, só lidos por um app novo.
class DadosDeVersaoMaisNova extends FormatException {
  DadosDeVersaoMaisNova(int versao)
      : super('estes dados são da versão $versao do formato, mas este app '
            'só entende até a $versaoAtual; atualize o app');
}

/// Lançada por [Repositorio.carregar] quando há dados salvos mas eles não podem
/// ser lidos. A implementação tenta guardar uma cópia de [bruto] antes de
/// lançar; [copiaGuardada] diz se conseguiu. Sem cópia, "começar do zero"
/// perde o original: a tela só o oferece com aviso explícito e junto de
/// "copiar dados" (senão, com o armazenamento cheio, não haveria saída).
class DadosCorrompidos implements Exception {
  final String bruto;
  final Object causa;
  final bool copiaGuardada;
  const DadosCorrompidos(this.bruto, this.causa, {required this.copiaGuardada});
  @override
  String toString() => 'Dados corrompidos: $causa';
}

/// Lançada por [Repositorio.salvar] quando os dados não foram gravados.
class FalhaAoSalvar extends ErroDoApp {
  const FalhaAoSalvar(super.motivo);
}

/// Onde os dados moram. Para trocar SharedPreferences por SQLite ou nuvem,
/// implemente esta interface e passe a nova classe ao Store em main.dart.
abstract interface class Repositorio {
  Future<Dados> carregar();
  Future<void> salvar(Dados dados);
}
