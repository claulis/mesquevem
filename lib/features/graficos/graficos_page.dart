import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../state/privacidade.dart';
import '../../state/store.dart';
import '../previsao/previsao.dart';
import '../previsao/resumo.dart';
import 'graficos.dart';

// Paleta categórica validada para daltonismo (claro / escuro), sempre na
// mesma ordem. O vermelho fica de fora: é o aviso de "acima do limite".
const _claro = [
  Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100), //
  Color(0xFFE87BA4), Color(0xFF008300), Color(0xFF6250D6),
];
const _escuro = [
  Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500), //
  Color(0xFFD55181), Color(0xFF008300), Color(0xFF9085E9),
];
List<Color> _paleta(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _escuro : _claro;

const _semDados = Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Text('Sem gastos para mostrar'));
const _diasDaSemana = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

// Textos do ⓘ de cada gráfico: o que mostra, como ler e cuidados.
const ajudaSeisMeses = 'Cada coluna é o total gasto em um mês, dos 5 '
    'anteriores até o mês na tela. O número em cima é o total (mil = '
    'milhares); toque na coluna para o valor exato.\n\n'
    'A linha horizontal é o teto: coluna acima dela = mês que estourou.\n\n'
    'A coluna clara ("prev.") é a previsão para o mês que vem, e só aparece '
    'quando a tela está no mês atual.\n\n'
    'Como ler: colunas descendo = a família está gastando menos. O mês '
    'atual ainda está em andamento, então costuma ser menor.';

const ajudaRitmo = 'A linha cheia é o gasto somado dia a dia no mês: no '
    'dia 10, mostra tudo o que foi gasto do dia 1 ao 10. O ponto é o dia de '
    'hoje.\n\n'
    'A linha tracejada é a referência: com teto, o ritmo ideal (sai do zero '
    'e chega ao teto no último dia); sem teto, o mesmo acumulado do mês '
    'anterior.\n\n'
    'Como ler: linha cheia acima da tracejada = gastando mais rápido que o '
    'ideal (ou que o mês passado); abaixo = dentro do ritmo. Degraus altos '
    'são dias de gasto grande.';

const ajudaGastador = 'Quanto cada pessoa da família gastou no mês na '
    'tela, do maior para o menor. "Todos" são os gastos lançados sem '
    'gastador.\n\n'
    'Como ler: mostra quem mais pesa no orçamento do mês. Para comparar de '
    'forma justa, lance cada gasto com o gastador certo; um "Todos" grande '
    'esconde quem gastou.';

const ajudaPizzaGastador = 'A pizza mostra a parte de cada pessoa no gasto '
    'do mês, com o nome, a % e o valor. No mês atual conta só o que já foi '
    'gasto até hoje; parcelas e gastos com data futura ficam de fora.\n\n'
    'Como ler: fatia grande = quem mais pesa no mês. "Todos" são os gastos '
    'lançados sem gastador. Para dividir um gasto entre várias pessoas, marque '
    'os gastadores ao lançar.';

const ajudaCategorias ='Para cada categoria, duas barras: a primeira é '
    'o gasto no mês na tela e a segunda é a média dos 3 meses anteriores.\n\n'
    'Como ler: primeira barra maior que a segunda = a categoria está acima '
    'do normal neste mês; menor = abaixo. É aqui que se vê onde o mês '
    'fugiu do padrão.\n\n'
    'Cuidado: no mês atual, ainda em andamento, as barras do mês tendem a '
    'ser menores que a média.';

const ajudaCalor = 'Cada quadrado é um dia do mês, na cor do quanto se '
    'gastou nele: verde = pouco, amarelo = médio, vermelho = muito. Cinza = '
    'nenhum gasto. Toque no dia para ver o valor.\n\n'
    'Com teto, a régua é o quanto cabe por dia (teto ÷ dias do mês): '
    'amarelo é um dia no limite e vermelho é o dobro ou mais. Sem teto, '
    'vermelho é o dia que mais gastou no mês.\n\n'
    'Como ler: vermelhos repetidos no mesmo dia da semana mostram um hábito '
    '(feira, saída de fim de semana); um vermelho isolado costuma ser uma '
    'compra grande.';

const ajudaEventos = 'Para cada evento (Natal, viagem, aniversário...), '
    'duas barras: o total gasto nele no ano do mês na tela e no ano '
    'anterior. Os mais caros deste ano vêm primeiro.\n\n'
    'Como ler: primeira barra maior = o evento ficou mais caro que no ano '
    'passado. Só a segunda = ainda não aconteceu (ou não foi lançado) neste '
    'ano.\n\n'
    'Cuidados: o ano é o do calendário (janeiro a dezembro), então em '
    'novembro o Natal deste ano ainda está incompleto. Só entram os gastos '
    'lançados com o evento marcado.\n\n'
    'Para que serve: planejar o próximo. Se o Natal passado custou R\$ '
    '1.200, dá para guardar aos poucos nos meses anteriores.';

const ajudaComposicao = 'A rosca divide o total do mês na tela entre as '
    'categorias: cada fatia é a parte de uma categoria, com a % e o valor '
    'na legenda. As 7 maiores aparecem com cor; o resto é somado em '
    '"Outras", em cinza.\n\n'
    'Como ler: mostra para onde vai a maior parte do dinheiro. Para cortar '
    'gastos, comece pelas fatias maiores.';

const ajudaSemana = 'Cada coluna é a soma de tudo o que foi gasto naquele '
    'dia da semana (D, S, T, Q, Q, S, S) nos últimos 12 meses. Cada dia da '
    'semana aparece umas 52 vezes nesse período, então as colunas são '
    'comparáveis.\n\n'
    'Como ler: a coluna mais alta é o dia em que a família mais gasta. Fim '
    'de semana alto = lazer e saídas; um dia útil alto costuma ser o dia do '
    'mercado ou de uma conta fixa. Colunas parecidas = gastos espalhados.\n\n'
    'Cuidados: vale a data lançada no gasto (lançar vários de uma vez com a '
    'data de hoje infla o dia de hoje), e uma compra grande isolada sobe '
    'uma coluna sozinha.';

/// Os gráficos do mês que estava na tela principal. Tocar numa barra ou num
/// dia mostra o valor.
class GraficosPage extends StatelessWidget {
  final DateTime mes;
  const GraficosPage(this.mes, {super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<Privacidade?>();
    final store = context.watch<Store>();
    final cs = store.compras;
    final hoje = DateTime.now();
    final atual = mes.year == hoje.year && mes.month == hoje.month;
    final cor = _paleta(context);
    final nomeMes = '${meses[mes.month - 1]}/${mes.year}';
    final teto = store.teto;

    final seis = totaisMensais(cs, mes);
    final (previsto, _) = previsao(cs, hoje);

    final dia = porDia(cs, mes);
    final acum = acumulado(dia);
    final serie = atual ? acum.take(hoje.day).toList() : acum;
    final (ref, rotuloRef) = teto != null
        ? (
            [for (var i = 1; i <= dia.length; i++) teto * i / dia.length],
            'ritmo ideal até o teto'
          )
        : (
            acumulado(porDia(cs, DateTime(mes.year, mes.month - 1))),
            'mês anterior'
          );

    final gastadores = porGastador(cs, mes, store.nomeGastador).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final doMes = gastoDoMes(cs, mes).porCategoria;
    final media = mediaPorCategoria(cs, mes);
    final cats = {...doMes.keys, ...media.keys}.toList()
      ..sort((a, b) => (doMes[b] ?? 0).compareTo(doMes[a] ?? 0));

    final eventos = eventosPorAno(cs, mes.year).entries.toList()
      ..sort((a, b) => b.value.$1.compareTo(a.value.$1));
    final semana = porDiaDaSemana(cs, mes);

    return Scaffold(
      appBar: AppBar(title: Text('Gráficos · $nomeMes')),
      body: ListView(padding: const EdgeInsets.fromLTRB(8, 8, 8, 24), children: [
        _Cartao(
          'Últimos 6 meses',
          [
            if (teto != null) 'linha: teto',
            if (atual) 'clara: previsão do mês que vem',
          ].join(' · '),
          _Colunas([
            for (final (m, t) in seis) (meses[m.month - 1].substring(0, 3), t),
            if (atual) ('prev.', previsto),
          ], cor: cor[0], linha: teto, ultimaClara: atual),
          ajuda: ajudaSeisMeses,
        ),
        _Cartao(
            'Ritmo do mês',
            'cheia: gasto acumulado · tracejada: $rotuloRef',
            _Ritmo(serie, ref,
                dias: dia.length, cor: cor[0], rotuloRef: rotuloRef),
            ajuda: ajudaRitmo),
        _Cartao(
            'Por gastador',
            nomeMes,
            gastadores.isEmpty
                ? _semDados
                : _Barras([for (final e in gastadores) (e.key, e.value)],
                    cor[0]),
            ajuda: ajudaGastador),
        _Cartao(
            'Pizza por gastador',
            atual ? '$nomeMes · até agora' : nomeMes,
            _Rosca(composicao(porGastadorAte(cs, mes, store.nomeGastador, hoje)),
                cor),
            ajuda: ajudaPizzaGastador),
        _Cartao(
            'Categorias: mês × média',
            'média dos 3 meses anteriores',
            cats.isEmpty
                ? _semDados
                : _Pares([
                    for (final k in cats)
                      (
                        k.isEmpty ? 'Sem categoria' : k,
                        doMes[k] ?? 0,
                        media[k] ?? 0
                      )
                  ], legenda: (nomeMes, 'média'), cores: (cor[0], cor[1])),
            ajuda: ajudaCategorias),
        _Cartao('Mapa de calor', 'quanto cada dia do mês gastou',
            _Calor(mes, dia,
                porDiaIdeal: teto == null ? null : teto / dia.length),
            ajuda: ajudaCalor),
        _Cartao(
            'Custo por evento',
            '${mes.year} × ${mes.year - 1}',
            eventos.isEmpty
                ? _semDados
                : _Pares([
                    for (final e in eventos) (e.key, e.value.$1, e.value.$2)
                  ], legenda: ('${mes.year}', '${mes.year - 1}'),
                    cores: (cor[0], cor[1])),
            ajuda: ajudaEventos),
        _Cartao('Composição por categoria', nomeMes,
            _Rosca(composicao(doMes), cor),
            ajuda: ajudaComposicao),
        _Cartao(
            'Por dia da semana',
            'total dos últimos 12 meses',
            _Colunas([for (var i = 0; i < 7; i++) (_diasDaSemana[i], semana[i])],
                cor: cor[0]),
            ajuda: ajudaSemana),
      ]),
    );
  }
}

class _Cartao extends StatelessWidget {
  final String titulo, sub, ajuda;
  final Widget filho;
  const _Cartao(this.titulo, this.sub, this.filho, {required this.ajuda});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(titulo, style: t.titleMedium)),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Como ler: $titulo',
              visualDensity: VisualDensity.compact,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(titulo),
                  content: SingleChildScrollView(child: Text(ajuda)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK')),
                  ],
                ),
              ),
            ),
          ]),
          if (sub.isNotEmpty) Text(sub, style: t.bodySmall),
          const SizedBox(height: 12),
          filho,
        ]),
      ),
    );
  }
}

/// Legenda com a cor ao lado do nome: a cor nunca é a única pista.
class _Legenda extends StatelessWidget {
  final List<(Color, String)> itens;
  const _Legenda(this.itens);

  @override
  Widget build(BuildContext context) => Wrap(spacing: 16, children: [
        for (final (c, n) in itens)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(n, style: Theme.of(context).textTheme.bodySmall),
          ]),
      ]);
}

Widget _dica(String msg, Widget filho) => Tooltip(
    message: msg, triggerMode: TooltipTriggerMode.tap, child: filho);

/// Colunas verticais com o valor curto em cima; [linha] (o teto) atravessa
/// o gráfico na altura dele. [ultimaClara]: a última coluna é uma previsão.
class _Colunas extends StatelessWidget {
  final List<(String, double)> itens;
  final Color cor;
  final double? linha;
  final bool ultimaClara;
  const _Colunas(this.itens,
      {required this.cor, this.linha, this.ultimaClara = false});

  @override
  Widget build(BuildContext context) {
    final maxV = [for (final i in itens) i.$2, linha ?? 0].reduce(max);
    if (maxV <= 0) return _semDados;
    const alto = 120.0;
    final t = Theme.of(context).textTheme.labelSmall;
    final tinta = Theme.of(context).colorScheme.onSurface;
    return Column(children: [
      SizedBox(
        height: alto + 16,
        child: Stack(children: [
          // atrás das colunas: não corta os números em cima delas
          if (linha != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: alto * linha! / maxV,
              child: Container(height: 1.5, color: tinta.withValues(alpha: 0.6)),
            ),
          Positioned.fill(
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (i, (r, v)) in itens.indexed)
                Expanded(
                  child: _dica(
                    '$r: ${fmtValor(v)}',
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(fmtCurto(v), style: t, maxLines: 1),
                      Container(
                        height: alto * v / maxV,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: ultimaClara && i == itens.length - 1
                              ? cor.withValues(alpha: 0.3)
                              : cor,
                          border: ultimaClara && i == itens.length - 1
                              ? Border.all(color: cor, width: 1.5)
                              : null,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      Row(children: [
        for (final (r, _) in itens)
          Expanded(child: Text(r, style: t, textAlign: TextAlign.center)),
      ]),
    ]);
  }
}

Widget _barra(double v, double maxV, Color cor, {double alto = 14}) =>
    FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: maxV > 0 ? (v / maxV).clamp(0.0, 1.0) : 0,
      child: Container(
          height: alto,
          decoration: BoxDecoration(
              color: cor, borderRadius: BorderRadius.circular(4))),
    );

/// Barras horizontais: nome, barra e valor.
class _Barras extends StatelessWidget {
  final List<(String, double)> itens;
  final Color cor;
  const _Barras(this.itens, this.cor);

  @override
  Widget build(BuildContext context) {
    final maxV = itens.map((e) => e.$2).reduce(max);
    return Column(children: [
      for (final (n, v) in itens)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(
                width: 88, child: Text(n, overflow: TextOverflow.ellipsis)),
            Expanded(child: _barra(v, maxV, cor)),
            const SizedBox(width: 8),
            Text(fmtValor(v), style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
    ]);
  }
}

/// Dois valores por nome (este mês × média, este ano × anterior).
class _Pares extends StatelessWidget {
  final List<(String, double, double)> itens;
  final (String, String) legenda;
  final (Color, Color) cores;
  const _Pares(this.itens, {required this.legenda, required this.cores});

  @override
  Widget build(BuildContext context) {
    final maxV = [for (final (_, a, b) in itens) max(a, b)].reduce(max);
    final t = Theme.of(context).textTheme.bodySmall;
    Widget linha(double v, Color c) => Row(children: [
          Expanded(child: _barra(v, maxV, c, alto: 10)),
          const SizedBox(width: 8),
          SizedBox(
              width: 96,
              child: Text(fmtValor(v), style: t, textAlign: TextAlign.end)),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Legenda([(cores.$1, legenda.$1), (cores.$2, legenda.$2)]),
      for (final (n, a, b) in itens) ...[
        const SizedBox(height: 10),
        Text(n),
        const SizedBox(height: 2),
        linha(a, cores.$1),
        const SizedBox(height: 2),
        linha(b, cores.$2),
      ],
    ]);
  }
}

/// Gasto acumulado dia a dia (linha cheia) contra uma referência (tracejada).
class _Ritmo extends StatelessWidget {
  final List<double> serie, ref;
  final int dias;
  final Color cor;
  final String rotuloRef;
  const _Ritmo(this.serie, this.ref,
      {required this.dias, required this.cor, required this.rotuloRef});

  @override
  Widget build(BuildContext context) {
    if (serie.every((v) => v <= 0) && ref.every((v) => v <= 0)) {
      return _semDados;
    }
    final t = Theme.of(context).textTheme.bodySmall;
    final tinta = Theme.of(context).colorScheme.onSurface;
    final hoje = serie.length;
    final noDia = ref.isEmpty ? 0.0 : ref[min(hoje, ref.length) - 1];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 140,
        width: double.infinity,
        child: CustomPaint(
            painter: _RitmoPintor(serie, ref.take(dias).toList(), dias, cor,
                tinta.withValues(alpha: 0.5))),
      ),
      Row(children: [
        Text('dia 1', style: t),
        const Spacer(),
        Text('dia $dias', style: t),
      ]),
      const SizedBox(height: 8),
      Text('Dia $hoje: ${fmtValor(serie.isEmpty ? 0 : serie.last)} gastos · '
          '$rotuloRef: ${fmtValor(noDia)}'),
    ]);
  }
}

class _RitmoPintor extends CustomPainter {
  final List<double> serie, ref;
  final int dias;
  final Color cor, corRef;
  _RitmoPintor(this.serie, this.ref, this.dias, this.cor, this.corRef);

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = [...serie, ...ref, 1.0].reduce(max);
    Offset p(int i, double v) => Offset(
        dias <= 1 ? 0 : size.width * i / (dias - 1),
        size.height * (1 - v / maxV));
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height),
        Paint()..color = corRef.withValues(alpha: 0.3));
    // tracejada: um trecho sim, outro não (um por dia)
    final pr = Paint()
      ..color = corRef
      ..strokeWidth = 2;
    for (var i = 1; i < ref.length; i += 2) {
      canvas.drawLine(p(i - 1, ref[i - 1]), p(i, ref[i]), pr);
    }
    if (serie.isEmpty) return;
    final caminho = Path()..moveTo(p(0, serie[0]).dx, p(0, serie[0]).dy);
    for (var i = 1; i < serie.length; i++) {
      caminho.lineTo(p(i, serie[i]).dx, p(i, serie[i]).dy);
    }
    canvas.drawPath(
        caminho,
        Paint()
          ..color = cor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(
        p(serie.length - 1, serie.last), 4, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

const _verde = Color(0xFF66BB6A),
    _amarelo = Color(0xFFFDD835),
    _vermelho = Color(0xFFE53935);

/// Cor do mapa de calor para [t] de 0 (pouco: verde) a 1 (muito: vermelho),
/// passando pelo amarelo no meio.
Color corDoCalor(double t) {
  final x = t.clamp(0.0, 1.0);
  return x < 0.5
      ? Color.lerp(_verde, _amarelo, x * 2)!
      : Color.lerp(_amarelo, _vermelho, (x - 0.5) * 2)!;
}

/// Calendário do mês, cada dia de verde (pouco) a vermelho (muito). Com
/// teto, a régua é o quanto cabe por dia: amarelo = no limite diário,
/// vermelho = o dobro ou mais. Sem teto, é o dia que mais gastou. Tocar
/// mostra o valor.
class _Calor extends StatelessWidget {
  final DateTime mes;
  final List<double> dia;
  final double? porDiaIdeal;
  const _Calor(this.mes, this.dia, {this.porDiaIdeal});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme.labelSmall;
    final maxV = dia.reduce(max);
    // valor que vira vermelho
    final topo = porDiaIdeal != null ? 2 * porDiaIdeal! : maxV;
    final vazios = DateTime(mes.year, mes.month).weekday % 7;
    Widget amostra(Color c) => Container(
        width: 12,
        height: 12,
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)));
    return Column(children: [
      Row(children: [
        for (final d in _diasDaSemana)
          Expanded(child: Text(d, style: t, textAlign: TextAlign.center)),
      ]),
      const SizedBox(height: 4),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        children: [
          for (var i = 0; i < vazios; i++) const SizedBox(),
          for (final (i, v) in dia.indexed)
            _dica(
              '${i + 1}/${mes.month}: ${fmtValor(v)}',
              Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v <= 0
                      ? esquema.surfaceContainerHighest
                      : corDoCalor(topo > 0 ? v / topo : 0),
                  borderRadius: BorderRadius.circular(4),
                ),
                // texto escuro: legível no verde, no amarelo e no vermelho
                child: Text('${i + 1}',
                    style: t?.copyWith(
                        color: v > 0 ? Colors.black87 : esquema.onSurface)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      // legenda: a escala de cores com o que cada ponta significa
      Row(children: [
        amostra(esquema.surfaceContainerHighest),
        const SizedBox(width: 4),
        Text('sem gasto', style: t),
        const SizedBox(width: 12),
        Text('pouco', style: t),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                  colors: [_verde, _amarelo, _vermelho]),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text('muito', style: t),
      ]),
      if (porDiaIdeal != null) ...[
        const SizedBox(height: 4),
        Text('amarelo = ${fmtValor(porDiaIdeal!)} por dia (teto ÷ dias)',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    ]);
  }
}

/// Rosca com a fatia de cada categoria; legenda com nome, % e valor.
class _Rosca extends StatelessWidget {
  final List<(String, double)> fatias;
  final List<Color> paleta;
  const _Rosca(this.fatias, this.paleta);

  @override
  Widget build(BuildContext context) {
    if (fatias.isEmpty) return _semDados;
    final outras = Theme.of(context).colorScheme.outline;
    final cores = [
      // a 8ª fatia só existe como "Outras" (ver composicao): cinza
      for (var i = 0; i < fatias.length; i++)
        i < paleta.length ? paleta[i] : outras
    ];
    final total = fatias.fold(0.0, (s, f) => s + f.$2);
    final t = Theme.of(context).textTheme.bodySmall;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(
            painter: _RoscaPintor([for (final f in fatias) f.$2], cores)),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (i, (n, v)) in fatias.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: cores[i],
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 6),
                // valor embaixo do nome: ao lado não cabe em tela estreita
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n, overflow: TextOverflow.ellipsis),
                        Text('${(v / total * 100).round()}% · ${fmtValor(v)}',
                            style: t),
                      ]),
                ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

class _RoscaPintor extends CustomPainter {
  final List<double> valores;
  final List<Color> cores;
  _RoscaPintor(this.valores, this.cores);

  @override
  void paint(Canvas canvas, Size size) {
    const espessura = 22.0;
    final total = valores.fold(0.0, (s, v) => s + v);
    final r = Rect.fromLTWH(espessura / 2, espessura / 2,
        size.width - espessura, size.height - espessura);
    // pequena folga entre as fatias, para separar cores vizinhas
    final folga = valores.length > 1 ? 0.03 : 0.0;
    var inicio = -pi / 2;
    for (final (i, v) in valores.indexed) {
      final ang = 2 * pi * v / total;
      canvas.drawArc(
          r,
          inicio + folga / 2,
          max(ang - folga, 0.001),
          false,
          Paint()
            ..color = cores[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = espessura);
      inicio += ang;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
