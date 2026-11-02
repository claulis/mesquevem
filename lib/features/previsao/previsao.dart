import 'dart:math';
import '../../data/compra.dart';

int _mes(DateTime d) => d.year * 12 + d.month;
double _soma(Iterable<double> xs) => xs.fold(0.0, (a, b) => a + b);

/// Histórico considerado na previsão, em meses fechados.
const janelaMeses = 36;

/// Previsão do mês seguinte. O algoritmo é escolhido pelo número de meses
/// fechados de histórico (do primeiro mês com compra até o mês passado,
/// limitado aos últimos [janelaMeses]):
///   < 6  -> média móvel dos últimos 3 meses
///   6-23 -> suavização exponencial (alfa 0,5)
///   >=24 -> sazonal: mesmo mês do ano anterior x crescimento anual
// ponytail: sazonal ingênuo com ajuste de crescimento; trocar por Holt-Winters se o erro medido for alto.
(double, String) previsao(List<Compra> compras, DateTime hoje) {
  final totais = <int, double>{};
  for (final c in compras) {
    totais[_mes(c.data)] = (totais[_mes(c.data)] ?? 0) + c.valor;
  }
  final atual = _mes(hoje);
  // só os últimos [janelaMeses]: o sazonal usa 24 meses, então o resultado
  // não muda, e uma data absurda (ano -270000, de um backup editado) não faz
  // montar uma série de milhões de meses a cada vez que a Home é desenhada
  final fechados =
      totais.keys.where((k) => k < atual && k >= atual - janelaMeses);
  if (fechados.isEmpty) {
    return (totais[atual] ?? 0, 'total parcial do mês atual (sem histórico)');
  }

  // série contínua: meses sem compra contam como zero
  final s = [
    for (var k = fechados.reduce(min); k < atual; k++) totais[k] ?? 0.0
  ];
  final n = s.length;

  if (n < 6) {
    final u = s.skip(max(0, n - 3));
    return (_soma(u) / u.length, 'média móvel (3 meses)');
  }
  if (n < 24) {
    var nivel = s.first;
    for (final x in s.skip(1)) {
      nivel = 0.5 * x + 0.5 * nivel;
    }
    return (nivel, 'suavização exponencial');
  }
  final ultimoAno = _soma(s.sublist(n - 12));
  final anoAnterior = _soma(s.sublist(n - 24, n - 12));
  final crescimento = anoAnterior > 0 ? ultimoAno / anoAnterior : 1.0;
  return (s[n - 11] * crescimento, 'sazonal (mesmo mês do ano anterior)');
}
