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
}
