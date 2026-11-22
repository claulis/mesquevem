import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:compras/core/drive.dart';
import 'package:compras/core/erros.dart';

// Sem testWidgets: o binding de widgets troca o HttpClient por um falso.

/// Imita a API do Drive (appDataFolder com no máximo um arquivo).
class DriveFalso {
  late final HttpServer _s;
  String? conteudo, id;
  final pedidos = <String>[]; // "MÉTODO caminho"
  String tokenValido = 't1';
  int? forcarStatus;
  int tamanhoGigante = 0;

  String get base => 'http://127.0.0.1:${_s.port}';

  Future<void> iniciar() async {
    _s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _s.listen((req) async {
      final res = req.response;
      final corpo = await utf8.decodeStream(req);
      pedidos.add('${req.method} ${req.uri.path}');
      res.headers.contentType = ContentType.json;
      if (req.headers.value('authorization') != 'Bearer $tokenValido') {
        res.statusCode = 401;
        return res.close();
      }
      if (forcarStatus != null) {
        res.statusCode = forcarStatus!;
        return res.close();
      }
      const quando = '2026-11-22T10:30:00.000Z';
      final p = req.uri.path;
      if (req.method == 'GET' && p == '/drive/v3/files') {
        expect(req.uri.queryParameters['spaces'], 'appDataFolder');
        res.write(jsonEncode({
          'files': [
            if (id != null) {'id': id, 'modifiedTime': quando}
          ]
        }));
      } else if (req.method == 'GET' && p == '/drive/v3/files/$id') {
        if (tamanhoGigante > 0) {
          res.add(List.filled(tamanhoGigante, 32));
        } else {
          res.write(conteudo);
        }
      } else if (req.method == 'POST' && p == '/upload/drive/v3/files') {
        expect(req.headers.value('content-type'), startsWith('multipart/related'));
        expect(corpo, contains('"parents":["appDataFolder"]'));
        expect(corpo, contains('"name":"$arquivoBackup"'));
        id = 'arq1';
        conteudo = corpo.split('\r\n\r\n')[2].split('\r\n--').first;
        res.write(jsonEncode({'id': id, 'modifiedTime': quando}));
      } else if (req.method == 'PATCH' && p == '/upload/drive/v3/files/$id') {
        conteudo = corpo;
        res.write(jsonEncode({'id': id, 'modifiedTime': quando}));
      } else {
        res.statusCode = 404;
      }
      await res.close();
    });
  }

  Future<void> parar() => _s.close(force: true);
}

void main() {
  late DriveFalso srv;
  late List<bool> pedidosDeToken;
  late Drive drive;
  setUp(() async {
    srv = DriveFalso();
    await srv.iniciar();
    pedidosDeToken = [];
    drive = Drive((novo) async {
      pedidosDeToken.add(novo);
      return 't1';
    }, base: srv.base);
  });
  tearDown(() => srv.parar());

  test('sem backup: baixar devolve null; enviar cria e depois atualiza',
      () async {
    expect(await drive.baixar(), isNull);
    final quando = await drive.enviar('{"a":1}');
    expect(quando, DateTime.utc(2026, 11, 22, 10, 30).toLocal());
    expect(srv.conteudo, '{"a":1}');
    expect(srv.pedidos, contains('POST /upload/drive/v3/files'));

    await drive.enviar('{"a":2}');
    expect(srv.pedidos.last, 'PATCH /upload/drive/v3/files/arq1',
        reason: 'segunda vez atualiza o mesmo arquivo');
    final b = await drive.baixar();
    expect(b!.texto, '{"a":2}');
    expect(b.quando, quando);
    expect(pedidosDeToken, everyElement(isFalse), reason: 'sem 401, sem renovar');
  });

  test('token expirado (401): renova uma vez e repete', () async {
    var n = 0;
    final d = Drive((novo) async => (n++ == 0 && !novo) ? 'velho' : 't1',
        base: srv.base);
    expect(await d.baixar(), isNull);
    expect(srv.pedidos.length, 2, reason: '401 e depois o pedido de novo');
  });

  test('401 de novo após renovar: erro legível, sem laço', () async {
    final d = Drive((_) async => 'errado', base: srv.base);
    await expectLater(
        d.baixar(),
        throwsA(isA<ErroDoApp>().having(
            (e) => e.motivo, 'motivo', contains('recusou o acesso'))));
    expect(srv.pedidos.length, 2);
  });

  test('erro do servidor e resposta grande demais viram ErroDoApp', () async {
    srv.forcarStatus = 500;
    await expectLater(
        drive.baixar(),
        throwsA(isA<ErroDoApp>()
            .having((e) => e.motivo, 'motivo', contains('500'))));
    srv.forcarStatus = null;
    await drive.enviar('x');
    srv.tamanhoGigante = limiteDrive + 10;
    await expectLater(
        drive.baixar(),
        throwsA(isA<ErroDoApp>()
            .having((e) => e.motivo, 'motivo', contains('grande demais'))));
  });

  test('sem rede: mensagem para gente', () async {
    await srv.parar();
    await expectLater(
        drive.baixar(),
        throwsA(isA<ErroDoApp>()
            .having((e) => e.motivo, 'motivo', 'sem conexão com a internet')));
  });
}
