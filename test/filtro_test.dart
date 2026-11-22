import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/features/compras/filtro.dart';

void main() {
  final pao = Compra(DateTime(2026, 3, 1), 10,
      descricao: 'Pão', categoria: 'Alimentação', gastador: 'a');
  final cinema = Compra(DateTime(2026, 3, 15, 20), 40,
      descricao: 'Cinema', categoria: 'Lazer', evento: 'Férias', gastador: 'b');
  final paoFerias = Compra(DateTime(2026, 3, 31, 23), 12,
      descricao: 'pão de queijo', evento: 'Férias', gastador: 'a');
  final semDono = Compra(DateTime(2026, 4, 1), 5, descricao: 'Pão doce');
  final cs = [pao, cinema, paoFerias, semDono];
  final marco = DateTimeRange(
      start: DateTime(2026, 3, 1), end: DateTime(2026, 3, 31));

  test('sem filtro devolve tudo', () {
    expect(filtrar(cs), cs);
  });

  test('um filtro por vez', () {
    expect(filtrar(cs, texto: ' PAO '), [pao, paoFerias, semDono]);
    expect(filtrar(cs, texto: 'lazer'), [cinema], reason: 'acha a categoria');
    expect(filtrar(cs, periodo: marco), [pao, cinema, paoFerias],
        reason: 'os dois dias do período entram');
    expect(filtrar(cs, evento: 'Férias'), [cinema, paoFerias]);
    expect(filtrar(cs, gastador: 'a'), [pao, paoFerias]);
    expect(filtrar(cs, gastador: ''), [semDono], reason: '"Todos"');
  });

  test('combinações de 2, 3 e 4 filtros', () {
    expect(filtrar(cs, texto: 'pão', gastador: 'a'), [pao, paoFerias]);
    expect(filtrar(cs, texto: 'pão', periodo: marco, evento: 'Férias'),
        [paoFerias]);
    expect(
        filtrar(cs,
            texto: 'pao', periodo: marco, evento: 'Férias', gastador: 'a'),
        [paoFerias]);
    expect(filtrar(cs, texto: 'cinema', gastador: 'a'), isEmpty);
  });
}
