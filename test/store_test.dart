import 'package:flutter_test/flutter_test.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/state/store.dart';

class RepositorioMemoria implements Repositorio {
  Dados dados = Dados.padrao();
  int salvamentos = 0;
  @override
  Future<Dados> carregar() async => dados;
  @override
  Future<void> salvar(Dados d) async => salvamentos++;
}

void main() {
  late RepositorioMemoria repo;
  late Store store;
  setUp(() async {
    repo = RepositorioMemoria();
    store = Store(repo);
    await store.carregar();
  });

  test('salvarCompra com mesmo id atualiza em vez de duplicar', () async {
    final c = Compra(DateTime(2026, 9, 1), 10);
    await store.salvarCompra(c);
    await store.salvarCompra(Compra(DateTime(2026, 9, 1), 20, id: c.id));
    expect(store.compras.single.valor, 20);
    await store.removerCompra(c.id);
    expect(store.compras, isEmpty);
    expect(repo.salvamentos, 3);
  });

  test('renomear categoria atualiza as compras', () async {
    await store.salvarCompra(
        Compra(DateTime(2026, 9, 1), 10, categoria: 'Lazer', evento: 'Natal'));
    await store.renomearCategoria(TipoCategoria.compra, 'Lazer', ' Diversão ');
    await store.renomearCategoria(TipoCategoria.evento, 'Natal', 'Festas');
    expect(store.compras.single.categoria, 'Diversão');
    expect(store.compras.single.evento, 'Festas');
    expect(store.categorias(TipoCategoria.compra), contains('Diversão'));
  });

  test('categoria vazia ou duplicada é ignorada', () async {
    final antes = store.categorias(TipoCategoria.compra).length;
    await store.adicionarCategoria(TipoCategoria.compra, '  ');
    await store.adicionarCategoria(TipoCategoria.compra, 'Lazer');
    await store.renomearCategoria(TipoCategoria.compra, 'Outros', 'Lazer');
    expect(store.categorias(TipoCategoria.compra).length, antes);
    expect(repo.salvamentos, 0);
  });
}
