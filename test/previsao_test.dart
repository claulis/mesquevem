import 'package:flutter_test/flutter_test.dart';
import 'package:compras/data/compra.dart';
import 'package:compras/features/previsao/previsao.dart';

void main() {
  final hoje = DateTime(2026, 10, 3);

  test('sem histórico fechado: total do mês atual', () {
    expect(previsao([], hoje).$1, 0);
    final (v, m) = previsao([Compra(DateTime(2026, 10, 1), 50)], hoje);
    expect(v, 50);
    expect(m, contains('parcial')); // não se passa por previsão completa
  });

  test('< 6 meses: média móvel', () {
    final (v, m) = previsao([
      Compra(DateTime(2026, 9, 10), 300),
      Compra(DateTime(2026, 8, 5), 100),
      Compra(DateTime(2026, 8, 20), 100),
      Compra(DateTime(2026, 10, 1), 999), // mês atual não entra
    ], hoje);
    expect(v, 250);
    expect(m, contains('média'));
  });

  test('6 a 23 meses: suavização exponencial', () {
    final (v, m) = previsao(
        [for (var i = 0; i < 6; i++) Compra(DateTime(2026, 4 + i, 15), 100)],
        hoje);
    expect(v, 100);
    expect(m, contains('exponencial'));
  });

  test('>= 24 meses: sazonal com crescimento', () {
    // out/2024..set/2025 = 100 por mês; out/2025..set/2026 = 200 por mês
    final (v, m) = previsao([
      for (var i = 0; i < 24; i++)
        Compra(DateTime(2024, 10 + i, 15), i < 12 ? 100 : 200)
    ], hoje);
    expect(v, 400); // nov/2025 (200) x crescimento anual (2,0)
    expect(m, contains('sazonal'));
  });

  test(
      'data absurda de um backup não muda a previsão nem monta milhões de meses',
      () {
    final normais = [
      Compra(DateTime(2026, 7, 5), 100),
      Compra(DateTime(2026, 8, 5), 200),
      Compra(DateTime(2026, 9, 5), 300),
    ];
    final comLixo = [...normais, Compra(DateTime(-270000), 999)];
    expect(previsao(comLixo, hoje), previsao(normais, hoje));
    expect(previsao(comLixo, hoje).$2, contains('média móvel'));
  });

  test('histórico além da janela não altera o sazonal', () {
    // 40 meses: a janela de 36 cobre os 24 que o sazonal usa
    final lista = [
      for (var i = 0; i < 40; i++) Compra(DateTime(2023, 6 + i, 15), 100.0 + i)
    ];
    final (v, m) = previsao(lista, hoje);
    expect(m, contains('sazonal'));
    // nov/2025 = i 29 (129) x (soma dos últimos 12 / soma dos 12 anteriores)
    final ultimos = [for (var i = 28; i < 40; i++) 100.0 + i];
    final anteriores = [for (var i = 16; i < 28; i++) 100.0 + i];
    double soma(List<double> l) => l.fold(0.0, (a, b) => a + b);
    expect(v, closeTo(129 * soma(ultimos) / soma(anteriores), 1e-9));
  });
}
