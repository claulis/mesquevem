/// Erro previsto, com [motivo] já escrito para o usuário (ex.: falha ao gravar,
/// nome de categoria repetido). Erros de outros tipos são defeitos do app.
///
/// Dart puro (sem Flutter), para a camada de dados poder usar.
class ErroDoApp implements Exception {
  final String motivo;
  const ErroDoApp(this.motivo);
  @override
  String toString() => motivo;
}
