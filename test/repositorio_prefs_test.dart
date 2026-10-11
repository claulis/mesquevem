import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:compras/data/repositorio.dart';
import 'package:compras/data/repositorio_prefs.dart';

void main() {
  final compraSemId = {'data': '2026-09-01T00:00:00.000', 'valor': 10};

  Future<Map<String, dynamic>> salvo() async =>
      jsonDecode((await SharedPreferences.getInstance()).getString('dados')!);

  test('v0 (chave "compras") migra com categorias padrão e ids', () async {
    SharedPreferences.setMockInitialValues(
        {'compras': jsonEncode([compraSemId, compraSemId])});
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
      await expectLater(repo.carregar(),
          throwsA(isA<DadosCorrompidos>().having((e) => e.bruto, 'bruto', lixo)));
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
}
