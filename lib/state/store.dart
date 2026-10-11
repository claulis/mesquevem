import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/compra.dart';
import '../data/repositorio.dart';

enum TipoCategoria { compra, evento }

/// Estado do app e regras de negócio. As telas leem daqui e chamam os métodos;
/// nunca alteram as listas diretamente.
class Store extends ChangeNotifier {
  final Repositorio _repo;
  Dados _d = Dados.padrao();
  Store(this._repo);

  List<Compra> get compras => List.unmodifiable(_d.compras);
  List<String> categorias(TipoCategoria t) => List.unmodifiable(_lista(t));
  List<String> _lista(TipoCategoria t) =>
      t == TipoCategoria.compra ? _d.catCompra : _d.catEvento;

  Future<void> carregar() async {
    _d = await _repo.carregar();
    _ordenar();
    notifyListeners();
  }

  /// Todos os dados (compras e categorias) no formato do backup.
  String exportar() => const JsonEncoder.withIndent('  ').convert(_d);

  /// Substitui todos os dados pelos de um backup já validado ([Dados.deTexto]).
  Future<void> importar(Dados dados) {
    _d = dados;
    return _salvar();
  }

  /// Descarta os dados e volta ao padrão. Só para depois de [DadosCorrompidos]:
  /// o repositório já guardou uma cópia do original.
  Future<void> recomecar() {
    _d = Dados.padrao();
    return _salvar();
  }

  void _ordenar() => _d.compras.sort((a, b) => b.data.compareTo(a.data));

  Future<void> _salvar() {
    _ordenar();
    notifyListeners();
    return _repo.salvar(_d);
  }

  /// Insere ou, se já existir uma compra com o mesmo id, substitui.
  Future<void> salvarCompra(Compra c) {
    final i = _d.compras.indexWhere((x) => x.id == c.id);
    if (i < 0) {
      _d.compras.add(c);
    } else {
      _d.compras[i] = c;
    }
    return _salvar();
  }

  Future<void> removerCompra(String id) {
    _d.compras.removeWhere((c) => c.id == id);
    return _salvar();
  }

  Future<void> adicionarCategoria(TipoCategoria t, String nome) async {
    nome = nome.trim();
    if (nome.isEmpty || _lista(t).contains(nome)) return;
    _lista(t).add(nome);
    await _salvar();
  }

  /// Renomeia também nas compras já cadastradas.
  Future<void> renomearCategoria(
      TipoCategoria t, String antigo, String novo) async {
    novo = novo.trim();
    final l = _lista(t);
    final i = l.indexOf(antigo);
    if (i < 0 || novo.isEmpty || l.contains(novo)) return;
    l[i] = novo;
    for (final c in _d.compras) {
      if (t == TipoCategoria.evento && c.evento == antigo) c.evento = novo;
      if (t == TipoCategoria.compra && c.categoria == antigo) c.categoria = novo;
    }
    await _salvar();
  }

  Future<void> removerCategoria(TipoCategoria t, String nome) {
    _lista(t).remove(nome);
    return _salvar();
  }
}
