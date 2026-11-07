String fmtData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
/// Ligado pelo botão do olho (ver Privacidade): todo valor exibido vira uma
/// máscara de tamanho fixo, que não revela nem a ordem de grandeza.
bool valoresOcultos = false;
const mascaraValor = 'R\$ •••••';

String fmtValor(double v) =>
    valoresOcultos ? mascaraValor : 'R\$ ${fmtNumero(v)}';

/// Número com 2 casas, vírgula decimal e ponto de milhar ("1.234,50"), como
/// [lerValor] aceita.
String fmtNumero(double v) {
  if (!v.isFinite) return '$v';
  final [inteiro, centavos] = v.abs().toStringAsFixed(2).split('.');
  final milhar =
      inteiro.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');
  return '${v < 0 ? '-' : ''}$milhar,$centavos';
}

/// Maior valor aceito por [lerValor]: R$ 1 trilhão.
const valorMaximo = 1e12;

/// Lê um valor digitado em pt-BR ("12,5", "1.234,56", "R$ 10", ",5", "12,")
/// ou com ponto decimal ("12.50", "1,234.56"). Lança [FormatException] com uma
/// mensagem para o usuário se o valor for inválido, ambíguo ou não positivo.
///
/// Ponto e vírgula são tratados igual: com os dois, o último é o decimal; um
/// só deles repetido é milhar ("1.000.000", "1,000,000"); um só, uma vez e
/// seguido de exatamente 3 dígitos ("1.250", "1,250") é recusado como ambíguo.
double lerValor(String texto) {
  // só "R$" no início e espaços nas pontas; espaço no meio ("12 50") é erro,
  // não pode virar 1250
  var t = texto.trim();
  if (t.startsWith(r'R$')) t = t.substring(2).trimLeft();
  if (t.isEmpty) throw const FormatException('Informe o valor');
  if (!RegExp(r'^[\d.,]+$').hasMatch(t)) {
    throw const FormatException('Use só números, ponto ou vírgula');
  }
  const invalido = FormatException('Valor inválido');
  bool agrupado(String s, String sep) =>
      RegExp(r'^\d{1,3}(' + RegExp.escape(sep) + r'\d{3})+$').hasMatch(s);

  final seps = RegExp('[.,]').allMatches(t).map((m) => m[0]!).toList();
  var inteiro = t, decimal = '';
  if (seps.toSet().length == 2) {
    final ult = t.lastIndexOf(RegExp('[.,]'));
    final sep = t[ult], milhar = sep == ',' ? '.' : ',';
    final antes = t.substring(0, ult);
    if (antes.contains(sep)) throw invalido; // dois separadores decimais
    if (!agrupado(antes, milhar)) throw invalido;
    inteiro = antes.replaceAll(milhar, '');
    decimal = t.substring(ult + 1);
  } else if (seps.length > 1) {
    if (!agrupado(t, seps.first)) throw invalido;
    inteiro = t.replaceAll(seps.first, '');
  } else if (seps.length == 1) {
    final ult = t.indexOf(seps.first);
    inteiro = t.substring(0, ult);
    decimal = t.substring(ult + 1);
    if (decimal.length == 3 && RegExp(r'^[1-9]\d{0,2}$').hasMatch(inteiro)) {
      throw const FormatException(
          'Ambíguo: para milhar escreva 1.250,00; para centavos, 1,25');
    }
  }
  if (inteiro.isEmpty && decimal.isEmpty) throw invalido;
  if (decimal.length > 2) {
    throw const FormatException('Use no máximo 2 casas decimais');
  }
  final v = double.parse('${inteiro.isEmpty ? '0' : inteiro}.'
      '${decimal.isEmpty ? '0' : decimal}');
  // acima disso o double perde centavos e fmtValor passa a notação científica
  if (v > valorMaximo) throw const FormatException('Valor grande demais');
  if (v <= 0) throw const FormatException('Informe um valor maior que zero');
  return v;
}

const meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// Dias do mês [mes] (1-12) de [ano]; mês 13 vira janeiro do ano seguinte.
int diasNoMes(int ano, int mes) => DateTime(ano, mes + 1, 0).day;
