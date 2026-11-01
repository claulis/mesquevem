import 'compra.dart' show novoId;

enum Sexo {
  m('M', 'M'),
  f('F', 'F'),
  outro('O', 'Outro');

  final String json, rotulo;
  const Sexo(this.json, this.rotulo);
  static Sexo deJson(Object? s) => values.firstWhere((x) => x.json == s,
      orElse: () => throw FormatException('sexo inválido: $s'));
}

/// Pessoa do núcleo familiar a quem uma compra pode ser atribuída. Imutável.
class Gastador {
  final String id, nome;
  final DateTime aniversario;
  final Sexo sexo;
  Gastador(this.nome, this.aniversario, this.sexo, {String? id})
      : id = id ?? novoId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'aniversario': aniversario.toIso8601String(),
        'sexo': sexo.json,
      };

  factory Gastador.fromJson(Map<String, dynamic> j) => Gastador(
      (j['nome'] as String).trim(),
      DateTime.parse(j['aniversario']),
      Sexo.deJson(j['sexo']),
      id: j['id']);
}
