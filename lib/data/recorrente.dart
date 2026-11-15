import 'dart:math';
import '../core/format.dart';
import 'compra.dart';
import 'divisao.dart';

/// Quantos meses para trás, no máximo, um recorrente atrasado é lançado.
// ponytail: limite fixo; uma data absurda de backup não gera séculos de gastos
const atrasoMaximoMeses = 36;

/// Gasto que se repete todo mês no [dia] (limitado ao fim do mês). Imutável.
class Recorrente {
  final String id;
  final int dia;
  final double valor;
  final String descricao, categoria, evento;

  /// Ids dos gastadores entre os quais o valor é dividido; vazio = "Todos".
  final List<String> gastadores;

  /// Dia 1 do próximo mês a lançar.
  final DateTime proximo;

  Recorrente(this.dia, this.valor, this.proximo,
      {String? id,
      this.descricao = '',
      this.categoria = '',
      this.evento = '',
      this.gastadores = const []})
      : id = id ?? novoId() {
    if (dia < 1 || dia > 31) throw FormatException('dia inválido: $dia');
    if (!valor.isFinite) throw FormatException('valor inválido: $valor');
  }

  /// Data do lançamento no mês de [m].
  DateTime dataNoMes(DateTime m) =>
      DateTime(m.year, m.month, min(dia, diasNoMes(m.year, m.month)));

  /// Primeiro mês de um recorrente novo: o atual, se o dia ainda não passou
  /// (hoje conta); senão, o seguinte.
  static DateTime inicio(int dia, DateTime hoje) =>
      min(dia, diasNoMes(hoje.year, hoje.month)) >= hoje.day
          ? DateTime(hoje.year, hoje.month)
          : DateTime(hoje.year, hoje.month + 1);

  Recorrente copiaCom({DateTime? proximo}) => Recorrente(
      dia, valor, proximo ?? this.proximo,
      id: id,
      descricao: descricao,
      categoria: categoria,
      evento: evento,
      gastadores: gastadores);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dia': dia,
        'valor': valor,
        'descricao': descricao,
        'categoria': categoria,
        'evento': evento,
        'gastadores': gastadores,
        'proximo': proximo.toIso8601String(),
      };

  factory Recorrente.fromJson(Map<String, dynamic> j) {
    final p = DateTime.parse(j['proximo']).toLocal();
    return Recorrente(
      (j['dia'] as num).toInt(),
      (j['valor'] as num).toDouble(),
      DateTime(p.year, p.month),
      id: j['id'],
      descricao: j['descricao'] ?? '',
      categoria: (j['categoria'] as String? ?? '').trim(),
      evento: (j['evento'] as String? ?? '').trim(),
      gastadores: [for (final g in j['gastadores'] ?? const []) g as String],
    );
  }
}

/// Gastos de todos os meses cujo dia já chegou (até [hoje], inclusive) e os
/// recorrentes com o [Recorrente.proximo] avançado. Gastador que não está em
/// [existentes] sai da divisão; se não sobrar nenhum, o gasto fica "Todos".
(List<Compra>, List<Recorrente>) lancar(
    List<Recorrente> rs, Set<String> existentes, DateTime hoje) {
  final gastos = <Compra>[];
  final limite = DateTime(hoje.year, hoje.month - atrasoMaximoMeses);
  final fim = DateTime(hoje.year, hoje.month, hoje.day + 1);
  final novos = [
    for (final r in rs)
      () {
        var m = r.proximo.isBefore(limite) ? limite : r.proximo;
        while (r.dataNoMes(m).isBefore(fim)) {
          gastos.addAll(gerarGastos(
              data: r.dataNoMes(m),
              total: r.valor,
              gastadores: [
                for (final g in r.gastadores)
                  if (existentes.contains(g)) g
              ],
              descricao: r.descricao,
              categoria: r.categoria,
              evento: r.evento));
          m = DateTime(m.year, m.month + 1);
        }
        return m == r.proximo ? r : r.copiaCom(proximo: m);
      }()
  ];
  return (gastos, novos);
}
