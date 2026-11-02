import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:compras/state/fundo.dart';

void main() {
  late Directory pasta;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pasta = await Directory.systemTemp.createTemp('fundo');
  });
  tearDown(() => pasta.delete(recursive: true));

  test('opacidade escolhida é gravada e volta na próxima abertura', () async {
    final f = Fundo(() async => pasta);
    await f.carregar();
    expect(f.opacidade, Fundo.opacidadePadrao);
    await f.definirOpacidade(0.6);

    final depois = Fundo(() async => pasta);
    await depois.carregar();
    expect(depois.opacidade, 0.6);
  });

  test('opacidade fica entre 5% e 100%', () async {
    final f = Fundo(() async => pasta);
    await f.definirOpacidade(0);
    expect(f.opacidade, 0.05);
    await f.definirOpacidade(3);
    expect(f.opacidade, 1);
  });

  test('com mais de uma imagem sobrando, usa a mais recente', () async {
    // sobras de uma troca em que apagar a antiga falhou
    for (final ms in ['1700000000300', '1700000000100', '1700000000200']) {
      File('${pasta.path}/fundo-$ms').writeAsStringSync(ms);
    }
    final f = Fundo(() async => pasta);
    await f.carregar();
    expect(f.arquivo!.path, endsWith('fundo-1700000000300'));
  });
}
