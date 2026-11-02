import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/state/store.dart';

class RepositorioMemoria implements Repositorio {
  Dados dados = Dados.padrao();
  int salvamentos = 0;

  /// Se não nulo, [salvar] lança isto.
  Object? falhaAoSalvar;
  @override
  Future<Dados> carregar() async => dados;
  @override
  Future<void> salvar(Dados d) async {
    if (falhaAoSalvar != null) throw falhaAoSalvar!;
    salvamentos++;
    dados = d; // como um repositório de verdade: carregar() devolve o salvo
  }
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
    await store.editarCategoria(
        TipoCategoria.compra, 'Lazer', ' Diversão ', null);
    await store.editarCategoria(TipoCategoria.evento, 'Natal', 'Festas', null);
    expect(store.compras.single.categoria, 'Diversão');
    expect(store.compras.single.evento, 'Festas');
    expect(store.categorias(TipoCategoria.compra), contains('Diversão'));
  });

  test('categoria vazia, duplicada ou sumida é recusada com o motivo',
      () async {
    const t = TipoCategoria.compra;
    final antes = store.categorias(t);
    Matcher recusa(String m) => throwsA(
        isA<OperacaoRecusada>().having((e) => e.motivo, 'motivo', contains(m)));
    await expectLater(store.adicionarCategoria(t, '  '), recusa('Informe'));
    await expectLater(
        store.adicionarCategoria(t, 'Lazer'), recusa('Já existe'));
    await expectLater(
        store.editarCategoria(t, 'Outros', 'Lazer', null), recusa('Já existe'));
    await expectLater(store.editarCategoria(t, 'Sumiu', 'X', null),
        recusa('não existe mais'));
    expect(store.categorias(t), antes);
    expect(repo.salvamentos, 0);
  });

  group('falha ao salvar desfaz a alteração e repassa o erro', () {
    const falha = FalhaAoSalvar('disco cheio');
    late Compra existente;
    setUp(() async {
      existente = Compra(DateTime(2026, 9, 1), 10, categoria: 'Lazer');
      await store.salvarCompra(existente);
      repo.falhaAoSalvar = falha;
    });

    test('salvarCompra (nova e edição)', () async {
      await expectLater(
          store.salvarCompra(Compra(DateTime(2026, 9, 2), 5)), throwsA(falha));
      await expectLater(
          store
              .salvarCompra(Compra(DateTime(2026, 9, 1), 99, id: existente.id)),
          throwsA(falha));
      expect(store.compras.single.valor, 10);
    });

    test('removerCompra', () async {
      await expectLater(store.removerCompra(existente.id), throwsA(falha));
      expect(store.compras.length, 1);
    });

    test('categorias: adicionar, renomear (e compras) e remover', () async {
      final antes = store.categorias(TipoCategoria.compra);
      await expectLater(store.adicionarCategoria(TipoCategoria.compra, 'Nova'),
          throwsA(falha));
      await expectLater(
          store.editarCategoria(
              TipoCategoria.compra, 'Lazer', 'Diversão', null),
          throwsA(falha));
      await expectLater(store.removerCategoria(TipoCategoria.compra, 'Lazer'),
          throwsA(falha));
      expect(store.categorias(TipoCategoria.compra), antes);
      expect(store.compras.single.categoria, 'Lazer');
    });

    test('importar e recomecar', () async {
      await expectLater(
          store.importar(Dados.padrao()..catEvento.add('X')), throwsA(falha));
      await expectLater(store.recomecar(), throwsA(falha));
      expect(store.compras.length, 1);
      expect(store.categorias(TipoCategoria.evento), isNot(contains('X')));
    });

    test('a tela não é avisada nem vê a alteração antes de ela ser gravada',
        () async {
      var avisos = 0;
      store.addListener(() => avisos++);
      final remocao = store.removerCompra(existente.id);
      await Future<void>.delayed(Duration.zero);
      expect(store.compras.length, 1, reason: 'salvamento ainda em andamento');
      await expectLater(remocao, throwsA(falha));
      expect(avisos, 0);
      expect(store.compras.length, 1);
    });

    test('depois da falha o Store volta a salvar normalmente', () async {
      await expectLater(store.removerCompra(existente.id), throwsA(falha));
      repo.falhaAoSalvar = null;
      await store.removerCompra(existente.id);
      expect(store.compras, isEmpty);
    });
  });

  test('alterações sem await: a que falha não leva a seguinte junto', () async {
    repo.falhaAoSalvar = const FalhaAoSalvar('x');
    final a = store.salvarCompra(Compra(DateTime(2026, 9, 1), 1));
    final erro = expectLater(a, throwsA(isA<FalhaAoSalvar>()));
    // o salvamento da 1ª só roda depois deste ponto; a 2ª entra na fila antes
    final b = store.salvarCompra(Compra(DateTime(2026, 9, 2), 2));
    await erro;
    // a 2ª também falhou (o repositório ainda falha), mas partiu do estado
    // já corrigido da 1ª: nada sobra
    await expectLater(b, throwsA(isA<FalhaAoSalvar>()));
    expect(store.compras, isEmpty);

    repo.falhaAoSalvar = null;
    await store.salvarCompra(Compra(DateTime(2026, 9, 3), 3));
    expect(store.compras.map((c) => c.valor), [3]);
  });

  test('valor não finito: salvamento falha, é desfeito e não contamina',
      () async {
    final repoJson = _RepositorioQueCodifica();
    final s = Store(repoJson);
    await s.carregar();
    for (final v in [double.nan, double.infinity, double.negativeInfinity]) {
      await expectLater(
          s.salvarCompra(Compra(DateTime(2026, 9, 1), v)), throwsA(anything));
    }
    expect(s.compras, isEmpty);
    await s.salvarCompra(Compra(DateTime(2026, 9, 1), 3));
    expect(await s.exportar(), contains('"valor": 3.0'));
  });

  test('exportar espera o salvamento pendente e não leva o que foi desfeito',
      () async {
    final c = Compra(DateTime(2026, 9, 1), 10);
    await store.salvarCompra(c);
    repo.falhaAoSalvar = const FalhaAoSalvar('x');
    final remocao = store.removerCompra(c.id);
    final erro = expectLater(remocao, throwsA(isA<FalhaAoSalvar>()));
    final texto = store.exportar();
    await erro;
    expect(Dados.deTexto(await texto).compras.single.id, c.id);
  });

  test('renomear que vira duplicado enquanto espera na fila é recusado',
      () async {
    const t = TipoCategoria.compra;
    final add = store.adicionarCategoria(t, 'Feira');
    final ren = store.editarCategoria(t, 'Lazer', 'Feira', null);
    await add;
    await expectLater(ren, throwsA(isA<OperacaoRecusada>()));
    expect(store.categorias(t), containsAll(['Lazer', 'Feira']));
  });

  test('carregar espera a alteração em andamento e não é desfeito por ela',
      () async {
    repo.falhaAoSalvar = const FalhaAoSalvar('x');
    final alteracao = store.salvarCompra(Compra(DateTime(2026, 9, 1), 1));
    final erro = expectLater(alteracao, throwsA(isA<FalhaAoSalvar>()));
    repo.dados = Dados.padrao()..compras.add(Compra(DateTime(2026, 8, 1), 7));
    final carga = store.carregar();
    await erro;
    await carga;
    expect(store.compras.single.valor, 7);
  });

  test('operações sem efeito não salvam nem avisam a tela', () async {
    var avisos = 0;
    store.addListener(() => avisos++);
    await store.removerCompra('não existe');
    await store.removerCategoria(TipoCategoria.compra, 'não existe');
    await store.editarCategoria(TipoCategoria.compra, 'Lazer', ' Lazer ', null);
    expect(repo.salvamentos, 0);
    expect(avisos, 0);
  });

  test('nomeInvalido', () {
    const t = TipoCategoria.compra;
    expect(store.nomeInvalido(t, ' '), isNotNull);
    expect(store.nomeInvalido(t, ' Lazer '), isNotNull);
    expect(store.nomeInvalido(t, 'Lazer', atual: 'Lazer'), isNull);
    expect(store.nomeInvalido(t, 'Nova'), isNull);
  });

  test('edição de compra excluída enquanto esperava não a recria', () async {
    final c = Compra(DateTime(2026, 9, 1), 10);
    await store.salvarCompra(c);
    final remocao = store.removerCompra(c.id);
    final edicao = store
        .salvarCompra(Compra(DateTime(2026, 9, 1), 20, id: c.id), edicao: true);
    await remocao;
    await expectLater(
        edicao,
        throwsA(isA<OperacaoRecusada>()
            .having((e) => e.motivo, 'motivo', contains('excluída'))));
    expect(store.compras, isEmpty);
  });

  test('o que é salvo é o estado novo, já ordenado', () async {
    await store.salvarCompra(Compra(DateTime(2026, 8, 1), 1));
    await store.salvarCompra(Compra(DateTime(2026, 9, 1), 2));
    await store.removerCategoria(TipoCategoria.compra, 'Lazer');
    expect(repo.dados.compras.map((c) => c.valor), [2, 1]);
    expect(repo.dados.catCompra, isNot(contains('Lazer')));
    final outro = Store(repo);
    await outro.carregar();
    expect(outro.compras.map((c) => c.valor), [2, 1]);
  });

  test('data em UTC (com Z) é lida como hora local', () {
    final c = Compra.fromJson(
        {'id': 'a', 'data': '2026-09-30T23:30:00.000Z', 'valor': 1});
    expect(c.data.isUtc, isFalse);
    expect(c.data, DateTime.utc(2026, 9, 30, 23, 30).toLocal());
    final local = Compra.fromJson(
        {'id': 'b', 'data': '2026-09-30T23:30:00.000', 'valor': 1});
    expect(local.data, DateTime(2026, 9, 30, 23, 30), reason: 'local não muda');
  });

  test('copiaCom preserva todos os campos (pega campo novo esquecido)', () {
    final c = Compra(DateTime(2026, 9, 1, 10, 30), 12.5,
        descricao: 'd', categoria: 'c', evento: 'e');
    expect(c.copiaCom().toJson(), c.toJson());
    expect(c.copiaCom(id: 'x').toJson(), {...c.toJson(), 'id': 'x'});
  });

  test('alteração não mexe nas compras que a tela já recebeu', () async {
    await store
        .salvarCompra(Compra(DateTime(2026, 9, 1), 10, categoria: 'Lazer'));
    final antes = store.compras.single;
    await store.editarCategoria(
        TipoCategoria.compra, 'Lazer', 'Diversão', null);
    expect(antes.categoria, 'Lazer');
    expect(store.compras.single.categoria, 'Diversão');
    expect(store.compras.single.id, antes.id);
  });
}

/// Codifica como o repositório real, para que valores que o JSON não aceita
/// falhem no salvamento.
class _RepositorioQueCodifica extends RepositorioMemoria {
  @override
  Future<void> salvar(Dados d) async {
    jsonEncode(d);
    await super.salvar(d);
  }
}
