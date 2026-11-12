import 'package:flutter_test/flutter_test.dart';
import 'package:compras/data/divisao.dart';

double soma(Iterable<double> xs) => xs.fold(0.0, (s, x) => s + x);

void main() {
  final d = DateTime(2026, 1, 31);

  test('sem parcelas nem divisão: um gasto igual ao pedido', () {
    final r = gerarGastos(data: d, total: 50, descricao: 'Pão');
    expect(r.length, 1);
    expect(r.single.valor, 50);
    expect(r.single.data, d);
    expect(r.single.descricao, 'Pão');
    expect(r.single.gastador, '');
  });

  test('parcelas: soma exata, centavos que sobram nas primeiras', () {
    final r = gerarGastos(data: d, total: 100, parcelas: 3, descricao: 'TV');
    expect(r.map((c) => c.valor), [33.34, 33.33, 33.33]);
    expect(soma(r.map((c) => c.valor)).toStringAsFixed(2), '100.00');
    expect(r.map((c) => c.descricao), ['TV (1/3)', 'TV (2/3)', 'TV (3/3)']);
  });

  test('parcelas caem nos meses seguintes; dia 31 vira fim do mês', () {
    final r = gerarGastos(data: d, total: 90, parcelas: 3);
    expect(r.map((c) => c.data), [
      DateTime(2026, 1, 31),
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
    ]);
    final v = gerarGastos(data: DateTime(2026, 11, 15), total: 40, parcelas: 3);
    expect(v.map((c) => (c.data.year, c.data.month)),
        [(2026, 11), (2026, 12), (2027, 1)]);
  });

  test('sem descrição, parcelas ficam só com o número', () {
    final r = gerarGastos(data: d, total: 10, parcelas: 2);
    expect(r.map((c) => c.descricao), ['(1/2)', '(2/2)']);
  });

  test('divisão: um gasto por gastador, partes iguais e soma exata', () {
    final r = gerarGastos(data: d, total: 100, gastadores: ['a', 'b', 'c']);
    expect(r.map((c) => c.gastador), ['a', 'b', 'c']);
    expect(r.map((c) => c.valor), [33.34, 33.33, 33.33]);
  });

  test('parcelas × gastadores: cada parcela é dividida', () {
    final r = gerarGastos(
        data: d, total: 300, parcelas: 3, gastadores: ['a', 'b'],
        categoria: 'Casa', evento: 'Natal');
    expect(r.length, 6);
    expect(r.every((c) => c.valor == 50), isTrue);
    expect(r.every((c) => c.categoria == 'Casa' && c.evento == 'Natal'), isTrue);
    expect(r.map((c) => c.id).toSet().length, 6); // ids únicos
  });

  test('parcelas fora de 1..maxParcelas são recusadas', () {
    expect(() => gerarGastos(data: d, total: 10, parcelas: 0),
        throwsArgumentError);
    expect(() => gerarGastos(data: d, total: 10, parcelas: maxParcelas + 1),
        throwsArgumentError);
  });
}
