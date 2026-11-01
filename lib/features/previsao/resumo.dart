import '../../data/compra.dart';

/// Gastos do mês de [hoje]: total, por categoria de compra e por evento.
({
  double total,
  Map<String, double> porCategoria,
  Map<String, double> porEvento
}) gastoDoMes(List<Compra> compras, DateTime hoje) {
  var total = 0.0;
  final cat = <String, double>{}, ev = <String, double>{};
  for (final c in compras) {
    if (c.data.year != hoje.year || c.data.month != hoje.month) continue;
    total += c.valor;
    cat[c.categoria] = (cat[c.categoria] ?? 0) + c.valor;
    ev[c.evento] = (ev[c.evento] ?? 0) + c.valor;
  }
  return (total: total, porCategoria: cat, porEvento: ev);
}
