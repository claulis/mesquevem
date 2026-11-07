import '../../core/format.dart';
import '../../data/compra.dart';
import '../previsao/resumo.dart';

// Dados dos gráficos: funções puras (sem Flutter), cobertas por testes.

bool _doMes(Compra c, DateTime m) =>
    c.data.year == m.year && c.data.month == m.month;

/// Total de cada um dos [n] meses que terminam em [mes], do mais antigo ao
/// mais novo.
List<(DateTime, double)> totaisMensais(List<Compra> cs, DateTime mes,
        {int n = 6}) =>
    [
      for (var i = n - 1; i >= 0; i--)
        (
          DateTime(mes.year, mes.month - i),
          gastoDoMes(cs, DateTime(mes.year, mes.month - i)).total
        )
    ];

/// Gasto de cada dia do mês (índice 0 = dia 1).
List<double> porDia(List<Compra> cs, DateTime mes) {
  final d = List.filled(diasNoMes(mes.year, mes.month), 0.0);
  for (final c in cs) {
    if (_doMes(c, mes)) d[c.data.day - 1] += c.valor;
  }
  return d;
}

/// Soma acumulada: [1, 2, 3] → [1, 3, 6].
List<double> acumulado(List<double> xs) {
  var s = 0.0;
  return [for (final x in xs) s += x];
}

/// Gasto do mês por gastador, pelo nome ("Todos" para os sem gastador).
Map<String, double> porGastador(
    List<Compra> cs, DateTime mes, String Function(String id) nome) {
  final r = <String, double>{};
  for (final c in cs) {
    if (!_doMes(c, mes)) continue;
    final n = nome(c.gastador);
    r[n] = (r[n] ?? 0) + c.valor;
  }
  return r;
}

/// Média mensal por categoria nos [n] meses anteriores a [mes].
Map<String, double> mediaPorCategoria(List<Compra> cs, DateTime mes,
    {int n = 3}) {
  final soma = <String, double>{};
  for (var i = 1; i <= n; i++) {
    final m = gastoDoMes(cs, DateTime(mes.year, mes.month - i));
    for (final MapEntry(:key, :value) in m.porCategoria.entries) {
      soma[key] = (soma[key] ?? 0) + value;
    }
  }
  return soma.map((k, v) => MapEntry(k, v / n));
}

/// Por evento: (total no ano [ano], total no ano anterior). Gastos sem evento
/// ficam de fora.
Map<String, (double, double)> eventosPorAno(List<Compra> cs, int ano) {
  final r = <String, (double, double)>{};
  for (final c in cs) {
    if (c.evento.isEmpty || (c.data.year != ano && c.data.year != ano - 1)) {
      continue;
    }
    final (a, b) = r[c.evento] ?? (0.0, 0.0);
    r[c.evento] = c.data.year == ano ? (a + c.valor, b) : (a, b + c.valor);
  }
  return r;
}

/// Total por dia da semana nos [n] meses que terminam em [mes]; índice 0 =
/// domingo, como no calendário brasileiro.
List<double> porDiaDaSemana(List<Compra> cs, DateTime mes, {int n = 12}) {
  final inicio = DateTime(mes.year, mes.month - n + 1);
  final fim = DateTime(mes.year, mes.month + 1);
  final r = List.filled(7, 0.0);
  for (final c in cs) {
    if (c.data.isBefore(inicio) || !c.data.isBefore(fim)) continue;
    r[c.data.weekday % 7] += c.valor;
  }
  return r;
}

/// Fatias da rosca: as [max] maiores categorias do mês e o resto somado em
/// "Outras" (cores a mais confundiriam). Categoria vazia vira "Sem categoria".
List<(String, double)> composicao(Map<String, double> porCategoria,
    {int max = 7}) {
  final itens = [
    for (final MapEntry(:key, :value) in porCategoria.entries)
      if (value > 0) (key.isEmpty ? 'Sem categoria' : key, value)
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  if (itens.length <= max) return itens;
  final resto = itens.skip(max).fold(0.0, (s, e) => s + e.$2);
  return [...itens.take(max), ('Outras', resto)];
}
