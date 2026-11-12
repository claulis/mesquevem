import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/erros.dart';
import '../data/compra.dart';
import '../data/gastador.dart';
import '../data/repositorio.dart';

enum TipoCategoria {
  compra,
  evento;

  /// Como aparece na tela: no app a compra se chama "gasto".
  String get rotulo => this == compra ? 'gasto' : 'evento';
}

/// Lançada quando uma alteração não pode ser feita no estado atual (ex.: nome
/// de categoria que passou a existir enquanto o diálogo estava aberto).
class OperacaoRecusada extends ErroDoApp {
  const OperacaoRecusada(super.motivo);
}

/// Estado do app e regras de negócio. As telas leem daqui e chamam os métodos;
/// nunca alteram as listas diretamente.
class Store extends ChangeNotifier {
  final Repositorio _repo;
  Dados _d = Dados.padrao();
  Store(this._repo);

  // visões sem cópia: _d nunca é alterado no lugar, só substituído
  List<Compra> get compras => UnmodifiableListView(_d.compras);
  List<String> categorias(TipoCategoria t) =>
      UnmodifiableListView(_lista(_d, t));
  static List<String> _lista(Dados d, TipoCategoria t) =>
      t == TipoCategoria.compra ? d.catCompra : d.catEvento;
  static Map<String, double> _limites(Dados d, TipoCategoria t) =>
      t == TipoCategoria.compra ? d.limCompra : d.limEvento;

  /// Limite mensal da categoria, ou null se não tiver.
  double? limite(TipoCategoria t, String nome) => _limites(_d, t)[nome];
  Map<String, double> limites(TipoCategoria t) =>
      UnmodifiableMapView(_limites(_d, t));
  List<Gastador> get gastadores => UnmodifiableListView(_d.gastadores);
  double? get teto => _d.teto;

  /// Nome para mostrar do gastador de uma compra ("Todos" se vazio ou excluído).
  String nomeGastador(String id) =>
      _d.gastadores.where((g) => g.id == id).firstOrNull?.nome ?? 'Todos';

  /// Lê do repositório. Entra na mesma fila das alterações, para nunca
  /// trocar os dados no meio de um salvamento.
  Future<void> carregar() => _naFila(() async {
        final d = await _repo.carregar();
        _ordenar(d);
        _d = d;
        notifyListeners();
      });

  /// Todos os dados (compras e categorias) no formato do backup. Espera os
  /// salvamentos pendentes, para exportar só o que já está gravado.
  Future<String> exportar() =>
      _naFila(() async => const JsonEncoder.withIndent('  ').convert(_d));

  /// Substitui todos os dados pelos de um backup já validado ([Dados.deTexto]).
  Future<void> importar(Dados dados) => _naFila(() => _trocar(dados));

  /// Descarta os dados e volta ao padrão. Só para depois de [DadosCorrompidos]
  /// e com confirmação do usuário: se [DadosCorrompidos.copiaGuardada] for
  /// false, não há cópia do original e ele se perde.
  Future<void> recomecar() => _naFila(() => _trocar(Dados.padrao()));

  static void _ordenar(Dados d) =>
      d.compras.sort((a, b) => b.data.compareTo(a.data));

  // Carga, exportação e alterações rodam uma por vez, cada uma partindo do
  // estado deixado pela anterior.
  Future<void> _fila = Future.value();

  Future<T> _naFila<T>(Future<T> Function() tarefa) {
    final r = _fila.then((_) => tarefa());
    _fila = r.then((_) {}, onError: (_) {});
    return r;
  }

  /// Salva [novo] e só então o põe no lugar e avisa a tela. Se salvar falhar,
  /// o estado e a tela ficam como estavam: nunca mostram o que não foi gravado.
  Future<void> _trocar(Dados novo) async {
    _ordenar(novo);
    await _repo.salvar(novo);
    _d = novo;
    notifyListeners();
  }

  /// Aplica [mudar] numa cópia e a salva com [_trocar], verificando antes,
  /// contra o estado do momento (não o de quando a tela chamou):
  /// - [semEfeito] true: nada a fazer, termina sem erro;
  /// - [recusa] com motivo: lança [OperacaoRecusada].
  Future<void> _alterar(void Function(Dados d) mudar,
          {bool Function()? semEfeito, String? Function()? recusa}) =>
      _naFila(() async {
        if (semEfeito?.call() ?? false) return;
        final motivo = recusa?.call();
        if (motivo != null) throw OperacaoRecusada(motivo);
        final novo = _d.copia();
        mudar(novo);
        await _trocar(novo);
      });

  /// Insere ou, se já existir uma compra com o mesmo id, substitui. Com
  /// [edicao], a compra tem de existir: se foi excluída enquanto a edição
  /// esperava, lança [OperacaoRecusada] em vez de recriá-la.
  Future<void> salvarCompra(Compra c, {bool edicao = false}) => _alterar((d) {
        final i = d.compras.indexWhere((x) => x.id == c.id);
        if (i < 0) {
          d.compras.add(c);
        } else {
          d.compras[i] = c;
        }
      },
          recusa: () => edicao && !_d.compras.any((x) => x.id == c.id)
              ? 'este gasto foi excluído'
              : null);

  /// Adiciona várias compras novas de uma vez (parcelas, divisão): ou entram
  /// todas ou nenhuma.
  Future<void> salvarCompras(List<Compra> novas) =>
      _alterar((d) => d.compras.addAll(novas));

  /// Compra que já não existe: nada a fazer.
  Future<void> removerCompra(String id) =>
      _alterar((d) => d.compras.removeWhere((c) => c.id == id),
          semEfeito: () => !_d.compras.any((c) => c.id == id));

  /// Motivo para recusar [nome] como categoria do tipo [t], ou null se serve.
  /// [atual] é o nome que está sendo renomeado (manter o mesmo nome é válido).
  String? nomeInvalido(TipoCategoria t, String nome, {String? atual}) {
    nome = nome.trim();
    if (nome.isEmpty) return 'Informe um nome';
    if (nome != atual && _lista(_d, t).contains(nome)) {
      return 'Já existe uma categoria com esse nome';
    }
    return null;
  }

  /// Lança [OperacaoRecusada] se o nome for vazio ou já existir. A tela valida
  /// antes ([nomeInvalido]); aqui vale o estado no momento de aplicar.
  Future<void> adicionarCategoria(TipoCategoria t, String nome,
      {double? limite}) {
    nome = nome.trim();
    return _alterar((d) {
      _lista(d, t).add(nome);
      if (limite != null) _limites(d, t)[nome] = limite;
    }, recusa: () => nomeInvalido(t, nome));
  }

  /// Troca nome e [limite] (null = sem limite). O novo nome vale também nas
  /// compras já cadastradas. Nada mudou: não faz nada; nome inválido ou
  /// categoria que não existe mais lança [OperacaoRecusada].
  Future<void> editarCategoria(
      TipoCategoria t, String antigo, String novo, double? limite) {
    novo = novo.trim();
    return _alterar((d) {
      final l = _lista(d, t), lim = _limites(d, t);
      l[l.indexOf(antigo)] = novo;
      lim.remove(antigo);
      if (limite != null) lim[novo] = limite;
      for (var i = 0; i < d.compras.length; i++) {
        final c = d.compras[i];
        if (t == TipoCategoria.evento && c.evento == antigo) {
          d.compras[i] = c.copiaCom(evento: novo);
        }
        if (t == TipoCategoria.compra && c.categoria == antigo) {
          d.compras[i] = c.copiaCom(categoria: novo);
        }
      }
    },
        semEfeito: () => novo == antigo && limite == this.limite(t, antigo),
        recusa: () => _lista(_d, t).contains(antigo)
            ? nomeInvalido(t, novo, atual: antigo)
            : 'A categoria "$antigo" não existe mais');
  }

  /// Categoria que já não existe: nada a fazer.
  Future<void> removerCategoria(TipoCategoria t, String nome) => _alterar((d) {
        _lista(d, t).remove(nome);
        _limites(d, t).remove(nome);
      }, semEfeito: () => !_lista(_d, t).contains(nome));

  /// Insere ou substitui pelo id. Com [edicao], o gastador tem de existir.
  Future<void> salvarGastador(Gastador g, {bool edicao = false}) =>
      _alterar((d) {
        final i = d.gastadores.indexWhere((x) => x.id == g.id);
        if (i < 0) {
          d.gastadores.add(g);
        } else {
          d.gastadores[i] = g;
        }
      },
          recusa: () => edicao && !_d.gastadores.any((x) => x.id == g.id)
              ? 'este gastador foi excluído'
              : null);

  /// As compras dele passam para "Todos".
  Future<void> removerGastador(String id) => _alterar((d) {
        d.gastadores.removeWhere((g) => g.id == id);
        for (var i = 0; i < d.compras.length; i++) {
          if (d.compras[i].gastador == id) {
            d.compras[i] = d.compras[i].copiaCom(gastador: '');
          }
        }
      }, semEfeito: () => !_d.gastadores.any((g) => g.id == id));

  /// null remove o teto.
  Future<void> definirTeto(double? valor) =>
      _alterar((d) => d.teto = valor, semEfeito: () => valor == _d.teto);
}
