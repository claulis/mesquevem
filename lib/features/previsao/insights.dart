import 'dart:math';
import '../../core/format.dart';
import '../../data/compra.dart';
import '../../data/gastador.dart';
import 'resumo.dart';

typedef Insight = ({String texto, bool alerta});

/// Frases automáticas da tela principal, na ordem em que aparecem. Só entram
/// as que se aplicam aos dados (ex.: sem teto, nada sobre o teto).
List<Insight> insights({
  required List<Compra> compras,
  required DateTime hoje,
  required double? teto,
  required Map<String, double> limCompra,
  required Map<String, double> limEvento,
  required List<Gastador> gastadores,
  required double previsao,
}) {
  final r = <Insight>[];
  final mes = gastoDoMes(compras, hoje);
  final dias = diasNoMes(hoje.year, hoje.month);

  if (teto != null) {
    if (mes.total > 0) {
      final projecao = mes.total / hoje.day * dias;
      r.add((
        texto: 'No ritmo atual você fecha o mês em ${fmtValor(projecao)} '
            '(teto ${fmtValor(teto)})',
        alerta: projecao > teto,
      ));
    }
    if (mes.total > teto) {
      r.add((
        texto: 'Teto estourado em ${fmtValor(mes.total - teto)}',
        alerta: true
      ));
    } else {
      final restantes = dias - hoje.day + 1; // contando hoje
      r.add((
        texto: 'Pode gastar ${fmtValor((teto - mes.total) / restantes)} '
            'por dia até o fim do mês',
        alerta: false,
      ));
    }
  }

  // mesmo período do mês passado: do dia 1 até o dia de hoje (ou o último
  // dia daquele mês, se ele for mais curto)
  final ant = DateTime(hoje.year, hoje.month - 1);
  final ateDia = min(hoje.day, diasNoMes(ant.year, ant.month));
  final anterior = compras
      .where((c) =>
          c.data.year == ant.year &&
          c.data.month == ant.month &&
          c.data.day <= ateDia)
      .fold(0.0, (s, c) => s + c.valor);
  if (anterior > 0) {
    final pct = ((mes.total / anterior - 1) * 100).round();
    final nomeMes = meses[ant.month - 1];
    r.add((
      texto: pct == 0
          ? 'Até hoje você gastou o mesmo que no mesmo período de $nomeMes'
          : 'Até hoje: ${pct.abs()}% a ${pct > 0 ? 'mais' : 'menos'} que no '
              'mesmo período de $nomeMes',
      alerta: pct > 0,
    ));
  }

  for (final (lim, gastos) in [
    (limCompra, mes.porCategoria),
    (limEvento, mes.porEvento),
  ]) {
    for (final MapEntry(key: nome, value: l) in lim.entries) {
      final usado = (gastos[nome] ?? 0) / l;
      if (usado >= 0.8 && usado <= 1) {
        r.add((
          texto: '$nome já usou ${(usado * 100).floor()}% do limite',
          alerta: true
        ));
      }
    }
  }

  // categoria de compra que mais passou da média dos 3 meses fechados
  final passados = [
    for (var i = 1; i <= 3; i++)
      gastoDoMes(compras, DateTime(hoje.year, hoje.month - i)).porCategoria
  ];
  String? maisCresceu;
  var maiorExcesso = 0.0, mediaDela = 0.0;
  for (final MapEntry(key: nome, value: gasto) in mes.porCategoria.entries) {
    if (nome.isEmpty) continue;
    final media = passados.fold(0.0, (s, m) => s + (m[nome] ?? 0)) / 3;
    if (media > 0 && gasto - media > maiorExcesso) {
      (maisCresceu, maiorExcesso, mediaDela) = (nome, gasto - media, media);
    }
  }
  if (maisCresceu != null) {
    r.add((
      texto: '$maisCresceu: ${fmtValor(mes.porCategoria[maisCresceu]!)} '
          'neste mês, acima da média de ${fmtValor(mediaDela)} dos últimos '
          '3 meses',
      alerta: true,
    ));
  }

  final proximo = DateTime(hoje.year, hoje.month + 1).month;
  for (final g in gastadores.where((g) => g.aniversario.month == proximo)) {
    r.add((
      texto: 'Aniversário de ${g.nome} em ${meses[proximo - 1]}: '
          'reserve um valor',
      alerta: false
    ));
  }

  if (teto != null && previsao > teto) {
    r.add((
      texto: 'A previsão do mês que vem passa do teto em '
          '${fmtValor(previsao - teto)}',
      alerta: true,
    ));
  }
  return r;
}
