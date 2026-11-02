import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:compras/core/atualizacao.dart';
import 'package:compras/core/erros.dart';
import 'package:compras/state/atualizador.dart';

// Sem testWidgets aqui: o binding de widgets troca o HttpClient por um falso
// (sempre 400), e estes testes usam um servidor HTTP local de verdade.

/// Imita o GitHub: /apk redireciona para /cdn, que aceita Range + If-Range,
/// tem ETag e pode derrubar a conexão no meio.
class Servidor {
  late final HttpServer _s;
  Uint8List dados;
  String etag = '"v1"';

  /// Se não nulo, a próxima resposta para neste byte e a conexão cai.
  int? cortarEm;
  final pedidos = <String?>[]; // cabeçalho Range de cada pedido ao /cdn
  final status = <int>[];

  Servidor(this.dados);

  String get url => 'http://127.0.0.1:${_s.port}/apk';

  Future<void> iniciar() async {
    _s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _s.listen((req) async {
      final res = req.response;
      try {
        if (req.uri.path == '/apk') {
          res.statusCode = 302;
          res.headers.set('location', '/cdn?assinatura=${pedidos.length}');
          return await res.close();
        }
        final range = req.headers.value('range');
        final ifRange = req.headers.value('if-range');
        pedidos.add(range);
        var inicio = 0;
        if (range != null && (ifRange == null || ifRange == etag)) {
          inicio = int.parse(range.substring(6, range.length - 1));
        }
        if (inicio >= dados.length && range != null && inicio > 0) {
          status.add(416);
          res.statusCode = 416;
          return await res.close();
        }
        res.statusCode = inicio > 0 ? 206 : 200;
        status.add(res.statusCode);
        res.headers.set('etag', etag);
        if (inicio > 0) {
          res.headers.set('content-range',
              'bytes $inicio-${dados.length - 1}/${dados.length}');
        }
        res.contentLength = dados.length - inicio;
        final corte = cortarEm;
        if (corte != null && corte > inicio) {
          cortarEm = null;
          res.add(dados.sublist(inicio, corte));
          await res.flush();
          // fecha antes do Content-Length: o cliente vê a conexão cair
          (await res.detachSocket(writeHeaders: false)).destroy();
          return;
        }
        res.add(dados.sublist(inicio));
        await res.close();
      } catch (_) {
        // conexão derrubada de propósito
      }
    });
  }

  Future<void> parar() => _s.close(force: true);
}

Uint8List bytes(int n, [int semente = 7]) =>
    Uint8List.fromList(List.generate(n, (i) => (i * semente + i ~/ 7) % 256));

String sha(List<int> b) => sha256.convert(b).toString();

void main() {
  late Servidor srv;
  late Directory pasta;
  late List<String> instalados;
  final dados = bytes(2 * 1024 * 1024); // 2 MB

  setUp(() async {
    srv = Servidor(dados);
    await srv.iniciar();
    pasta = await Directory.systemTemp.createTemp('atualizador');
    instalados = [];
  });
  tearDown(() async {
    await srv.parar();
    await pasta.delete(recursive: true);
  });

  Atualizador novo(
          {String? sha256Esperado,
          Duration espera = const Duration(milliseconds: 20)}) =>
      Atualizador(
        verificar: () async =>
            Release(9, 'v1.0.0-9', srv.url, sha256Esperado ?? sha(dados)),
        pasta: () async => pasta,
        instalar: (c) async {
          instalados.add(c);
          return 'ok';
        },
        atual: 8,
        versao: '1.0.0-8',
        esperas: [espera],
        semDados: const Duration(seconds: 2),
        exigirHttps: false, // servidor local de teste é http
      );

  File apk() => File('${pasta.path}/atualizacao/mesquevem-v1.0.0-9.apk');
  File parte() =>
      File('${pasta.path}/atualizacao/mesquevem-v1.0.0-9.apk.parte');

  test('baixa, confere o SHA-256 e abre o instalador', () async {
    final a = novo();
    await a.atualizar();
    expect(a.fase, Fase.pronto);
    expect(await apk().readAsBytes(), dados);
    expect(instalados, [apk().path]);
    expect(srv.pedidos, [null]);
  });

  test('conexão cai em 40%: guarda o ponto e continua com Range', () async {
    final corte = (dados.length * 0.4).round();
    srv.cortarEm = corte;
    final a = novo();
    final fases = <Fase>[];
    a.addListener(() => fases.add(a.fase));
    await a.atualizar();

    expect(fases, contains(Fase.semConexao));
    expect(srv.pedidos, [null, 'bytes=$corte-'],
        reason: 'segundo pedido continua do ponto salvo');
    expect(srv.status, [200, 206]);
    expect(a.fase, Fase.pronto);
    expect(await apk().readAsBytes(), dados);
  });

  test('app fechado no meio: na próxima abertura continua sozinho', () async {
    final corte = (dados.length * 0.4).round();
    srv.cortarEm = corte;
    // primeira "sessão": cai e fica esperando a rede por muito tempo
    final antes = novo(espera: const Duration(hours: 1));
    final fimAntes = antes.atualizar();
    while (antes.fase != Fase.semConexao) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await parte().length(), corte);

    // "abre o app de novo": outro Atualizador, mesma pasta
    final depois = novo();
    await depois.retomarSalvo();
    expect(depois.fase, Fase.pronto);
    expect(srv.pedidos.last, 'bytes=$corte-');
    expect(await apk().readAsBytes(), dados);
    await antes.cancelar();
    await fimAntes;
  });

  test('arquivo mudou no servidor: If-Range não bate e baixa do zero',
      () async {
    final novos = bytes(dados.length, 13);
    final corte = (dados.length * 0.4).round();
    srv.cortarEm = corte;
    final a = Atualizador(
      verificar: () async => Release(9, 'v1.0.0-9', srv.url, sha(novos)),
      pasta: () async => pasta,
      instalar: (_) async => 'ok',
      atual: 8,
      esperas: const [Duration(milliseconds: 20)],
      semDados: const Duration(seconds: 2),
      exigirHttps: false,
    );
    a.addListener(() {
      if (a.fase == Fase.semConexao) {
        srv
          ..dados = novos
          ..etag = '"v2"';
      }
    });
    await a.atualizar();
    expect(srv.pedidos, [null, 'bytes=$corte-']);
    expect(srv.status, [200, 200], reason: 'ETag mudou: servidor manda tudo');
    expect(await apk().readAsBytes(), novos);
  });

  test('SHA-256 errado: tenta de novo uma vez e desiste', () async {
    final a = novo(sha256Esperado: 'nao-confere');
    await a.atualizar();
    expect(a.fase, Fase.erro);
    expect(a.erro, contains('corrompido'));
    expect(srv.pedidos.length, 2);
    expect(instalados, isEmpty);
    expect(await parte().exists(), isFalse);
  });

  test('sem conexão antes de começar: não baixa nada', () async {
    final a = Atualizador(
      verificar: () async => throw const ErroDoApp('sem conexão'),
      pasta: () async => pasta,
      atual: 8,
    );
    await a.atualizar();
    expect(a.fase, Fase.erro);
    expect(a.erro, startsWith('Sem conexão'));
    expect(srv.pedidos, isEmpty);
  });

  test('cancelar apaga o que foi baixado', () async {
    srv.cortarEm = 5000;
    final a = novo(espera: const Duration(hours: 1));
    final fim = a.atualizar();
    while (a.fase != Fase.semConexao) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await a.cancelar();
    await fim;
    expect(a.fase, Fase.ocioso);
    expect(await parte().exists(), isFalse);
  });

  test('versão já instalada: retomarSalvo limpa os restos', () async {
    await novo().atualizar();
    final instalada = Atualizador(pasta: () async => pasta, atual: 9);
    await instalada.retomarSalvo();
    expect(Directory('${pasta.path}/atualizacao').listSync(), isEmpty);
  });

  test('erro ao preparar a pasta não trava a tela (_rodando volta a false)',
      () async {
    // "pasta" que é um arquivo: criar atualizacao/ dentro dela falha
    final arquivo = File('${pasta.path}/nao-e-pasta')..writeAsStringSync('x');
    final a = Atualizador(
      verificar: () async => Release(9, 'v1.0.0-9', srv.url, sha(dados)),
      pasta: () async => Directory(arquivo.path),
      atual: 8,
      exigirHttps: false,
    );
    await a.atualizar();
    expect(a.fase, Fase.erro);
    expect(a.erro, contains('preparar o download'));
    expect(a.rodando, isFalse, reason: 'senão os botões ficam desativados');
    expect(srv.pedidos, isEmpty);
  });

  test('endereço sem https é recusado antes de baixar', () async {
    final a = Atualizador(
      verificar: () async => Release(9, 'v1.0.0-9', srv.url, sha(dados)),
      pasta: () async => pasta,
      atual: 8,
    );
    await a.atualizar();
    expect(a.fase, Fase.erro);
    expect(a.erro, contains('https'));
    expect(srv.pedidos, isEmpty);
    expect(a.rodando, isFalse);
  });

  test('ponto salvo com tag adulterada é ignorado na abertura', () async {
    final dir = Directory('${pasta.path}/atualizacao')..createSync();
    File('${dir.path}/mesquevem-x.json').writeAsStringSync(
        '{"tag": "../../fora-9", "build": 9, "apk": "${srv.url}", '
        '"sha256": null, "total": 0, "etag": null}');
    final a = novo();
    await a.retomarSalvo();
    expect(a.fase, Fase.ocioso);
    expect(srv.pedidos, isEmpty);
  });

  test('versão sem SHA-256 não é baixada', () async {
    final a = Atualizador(
      verificar: () async => Release(9, 'v1.0.0-9', srv.url),
      pasta: () async => pasta,
      atual: 8,
      exigirHttps: false,
    );
    await a.atualizar();
    expect(a.fase, Fase.erro);
    expect(a.erro, contains('SHA-256'));
    expect(srv.pedidos, isEmpty);
    expect(a.rodando, isFalse);
  });
}
