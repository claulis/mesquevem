import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/data/repositorio_prefs.dart';

void main() {
  final compraSemId = {'data': '2026-09-01T00:00:00.000', 'valor': 10};

  Future<Map<String, dynamic>> salvo() async =>
      jsonDecode((await SharedPreferences.getInstance()).getString('dados')!);

  test('v0 (chave "compras") migra com categorias padrão e ids', () async {
    SharedPreferences.setMockInitialValues({
      'compras': jsonEncode([compraSemId, compraSemId])
    });
    final d = await RepositorioPrefs().carregar();
    expect(d.compras.length, 2);
    expect(d.compras.map((c) => c.id).toSet().length, 2);
    expect(d.catCompra, isNotEmpty);
    expect((await salvo())['versao'], versaoAtual);
  });

  test('v1 ("dados" sem versão) ganha ids persistidos', () async {
    SharedPreferences.setMockInitialValues({
      'dados': jsonEncode({
        'compras': [compraSemId],
        'catCompra': ['A'],
        'catEvento': ['B'],
      })
    });
    final d = await RepositorioPrefs().carregar();
    expect(d.catCompra, ['A']);
    final j = await salvo();
    expect(j['versao'], versaoAtual);
    expect(j['compras'][0]['id'], d.compras.single.id);
  });

  test('corrompido: lança, guarda uma cópia só e não mexe no original',
      () async {
    const lixo = '{"compras": [{"data": "ontem"}]}';
    SharedPreferences.setMockInitialValues({'dados': lixo});
    final repo = RepositorioPrefs();
    for (var i = 0; i < 2; i++) {
      await expectLater(
          repo.carregar(),
          throwsA(
              isA<DadosCorrompidos>().having((e) => e.bruto, 'bruto', lixo)));
    }
    final p = await SharedPreferences.getInstance();
    final copias =
        p.getKeys().where((k) => k.startsWith(RepositorioPrefs.prefixoCopia));
    expect(copias.length, 1);
    expect(p.getString(copias.single), lixo);
    expect(p.getString('dados'), lixo);
  });

  test('sem dados: padrão', () async {
    SharedPreferences.setMockInitialValues({});
    expect((await RepositorioPrefs().carregar()).compras, isEmpty);
  });

  test('versão mais nova: não é corrupção, nada é copiado nem alterado',
      () async {
    final novo = jsonEncode({
      'versao': versaoAtual + 1,
      'compras': [],
      'catCompra': [],
      'catEvento': [],
    });
    SharedPreferences.setMockInitialValues({'dados': novo});
    await expectLater(
        RepositorioPrefs().carregar(), throwsA(isA<DadosDeVersaoMaisNova>()));
    final p = await SharedPreferences.getInstance();
    expect(p.getString('dados'), novo);
    expect(
        p.getKeys().where((k) => k.startsWith(RepositorioPrefs.prefixoCopia)),
        isEmpty);
  });

  group('armazenamento que recusa gravar', () {
    final legado = jsonEncode({
      'compras': [compraSemId],
      'catCompra': ['A'],
      'catEvento': ['B'],
    });
    setUp(() {
      SharedPreferencesStorePlatform.instance =
          _StoreQueRecusa({'flutter.dados': legado});
      SharedPreferences.resetStatic();
    });
    tearDown(() => SharedPreferences.setMockInitialValues({}));

    test('salvar lança FalhaAoSalvar e carregar lê o disco, não o cache',
        () async {
      await expectLater(RepositorioPrefs().salvar(Dados.padrao()),
          throwsA(isA<FalhaAoSalvar>()));
      // o setString deixou o valor recusado no cache em memória
      final p = await SharedPreferences.getInstance();
      expect(p.getString('dados'), isNot(legado));
      expect((await RepositorioPrefs().carregar()).catCompra, ['A']);
    });

    test('falha ao gravar a migração não impede de abrir os dados', () async {
      final d = await RepositorioPrefs().carregar();
      expect(d.compras.length, 1);
      expect(d.catCompra, ['A']);
      // a migração não foi gravada; a próxima abertura gera os mesmos ids
      final deNovo = await RepositorioPrefs().carregar();
      expect(deNovo.compras.single.id, d.compras.single.id);
    });
  });

  test('cópia antiga com valor que não é texto não atrapalha', () async {
    const lixo = '{lixo';
    SharedPreferences.setMockInitialValues(
        {'dados': lixo, '${RepositorioPrefs.prefixoCopia}1': 42});
    await expectLater(
        RepositorioPrefs().carregar(), throwsA(isA<DadosCorrompidos>()));
  });

  test('valor de outro tipo na chave: corrompido, com cópia', () async {
    SharedPreferences.setMockInitialValues({
      'dados': ['a', 'b']
    });
    await expectLater(
        RepositorioPrefs().carregar(),
        throwsA(isA<DadosCorrompidos>()
            .having((e) => e.copiaGuardada, 'copiaGuardada', true)
            // cópia fiel (JSON), não o toString "[a, b]"
            .having((e) => e.bruto, 'bruto', '["a","b"]')));
  });

  test('JSON que não é objeto: corrompido com causa legível', () async {
    SharedPreferences.setMockInitialValues({'dados': '[1, 2]'});
    await expectLater(
        RepositorioPrefs().carregar(),
        throwsA(isA<DadosCorrompidos>()
            .having((e) => e.causa, 'causa', isA<FormatException>())));
  });

  test('sem conseguir guardar a cópia: corrompido, mas avisa que não há cópia',
      () async {
    const lixo = '{"compras": [{"data": "ontem"}]}';
    SharedPreferencesStorePlatform.instance =
        _StoreQueRecusa({'flutter.dados': lixo});
    SharedPreferences.resetStatic();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    // a tela não oferece "começar do zero" sem cópia, mas "copiar dados" sim
    await expectLater(
        RepositorioPrefs().carregar(),
        throwsA(isA<DadosCorrompidos>()
            .having((e) => e.copiaGuardada, 'copiaGuardada', false)
            .having((e) => e.bruto, 'bruto', lixo)));
  });

  test('exceção do armazenamento vira FalhaAoSalvar', () async {
    SharedPreferencesStorePlatform.instance = _StoreQueLanca();
    SharedPreferences.resetStatic();
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    await expectLater(RepositorioPrefs().salvar(Dados.padrao()),
        throwsA(isA<FalhaAoSalvar>()));
  });

  test('ids repetidos (backup editado) ganham sufixo, igual a cada leitura',
      () {
    final j = {
      'versao': versaoAtual,
      'compras': [
        {...compraSemId, 'id': 'x'},
        {...compraSemId, 'id': 'x'},
        {...compraSemId, 'id': 'x-2'},
      ],
      'catCompra': ['A'],
      'catEvento': ['B'],
    };
    final ids = Dados.fromJson(j).compras.map((c) => c.id).toList();
    expect(ids.toSet().length, 3);
    expect(Dados.fromJson(j).compras.map((c) => c.id).toList(), ids);
  });

  test('ids da migração não colidem com ids já existentes', () {
    final d = Dados.fromJson({
      'compras': [
        {...compraSemId, 'id': 'v1-1'},
        compraSemId,
        {...compraSemId, 'id': 'v1-2-'},
        compraSemId,
      ],
      'catCompra': ['A'],
      'catEvento': ['B'],
    });
    expect(d.compras.map((c) => c.id).toSet().length, 4);
  });

  test('migrar não altera o mapa recebido', () {
    final j = <String, dynamic>{
      'compras': [Map<String, dynamic>.of(compraSemId)],
      'catCompra': ['A'],
      'catEvento': ['B'],
    };
    final d = Dados.fromJson(j);
    expect((j['compras'] as List).single, isNot(contains('id')));
    expect(d.compras.single.id, isNotEmpty);
  });
}

class _StoreQueRecusa extends InMemorySharedPreferencesStore {
  _StoreQueRecusa([Map<String, Object>? dados]) : super.withData(dados ?? {});
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

class _StoreQueLanca extends InMemorySharedPreferencesStore {
  _StoreQueLanca() : super.empty();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw Exception('disco removido');
}
