import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'erros.dart';

/// Nome do backup na pasta oculta do app no Drive (appDataFolder).
const arquivoBackup = 'mesquevem-backup.json';

/// Maior resposta aceita do Drive (o backup é texto pequeno).
const limiteDrive = 20 * 1024 * 1024;

/// Backup no Google Drive do próprio usuário, na pasta que só o app vê.
/// REST direto ([HttpClient]), sem biblioteca extra. [token] devolve o
/// access token do escopo drive.appdata; com `novo` true, pede um novo (o
/// anterior expirou).
class Drive {
  final Future<String> Function(bool novo) token;
  final String base;
  Drive(this.token, {this.base = 'https://www.googleapis.com'});

  /// Último backup no Drive, ou null se ainda não há.
  Future<({String texto, DateTime quando})?> baixar() async {
    final a = await _achar();
    if (a == null) return null;
    final (_, texto) =
        await _pedir('GET', '/drive/v3/files/${a.id}?alt=media');
    return (texto: texto, quando: a.quando);
  }

  /// Grava [texto] no backup (cria na primeira vez) e devolve quando ficou
  /// salvo no Drive.
  Future<DateTime> enviar(String texto) async {
    final a = await _achar();
    final String corpo;
    if (a == null) {
      const fronteira = 'mesquevem-fronteira';
      final meta = jsonEncode({
        'name': arquivoBackup,
        'parents': ['appDataFolder'],
      });
      (_, corpo) = await _pedir(
          'POST',
          '/upload/drive/v3/files?uploadType=multipart&fields=id,modifiedTime',
          corpo: '--$fronteira\r\n'
              'Content-Type: application/json; charset=UTF-8\r\n\r\n'
              '$meta\r\n'
              '--$fronteira\r\n'
              'Content-Type: application/json\r\n\r\n'
              '$texto\r\n'
              '--$fronteira--',
          tipo: 'multipart/related; boundary=$fronteira');
    } else {
      (_, corpo) = await _pedir(
          'PATCH',
          '/upload/drive/v3/files/${a.id}'
              '?uploadType=media&fields=id,modifiedTime',
          corpo: texto,
          tipo: 'application/json');
    }
    return _data(jsonDecode(corpo) as Map<String, dynamic>);
  }

  Future<({String id, DateTime quando})?> _achar() async {
    final q = Uri.encodeQueryComponent("name='$arquivoBackup' and trashed=false");
    final (_, corpo) = await _pedir(
        'GET',
        '/drive/v3/files?spaces=appDataFolder&q=$q'
            '&fields=files(id,modifiedTime)&orderBy=modifiedTime desc');
    try {
      final fs = (jsonDecode(corpo) as Map<String, dynamic>)['files'] as List;
      if (fs.isEmpty) return null;
      final f = fs.first as Map<String, dynamic>;
      return (id: f['id'] as String, quando: _data(f));
    } on TypeError {
      throw const ErroDoApp('resposta inesperada do Google Drive');
    }
  }

  static DateTime _data(Map<String, dynamic> j) =>
      DateTime.tryParse(j['modifiedTime'] as String? ?? '')?.toLocal() ??
      DateTime.now();

  /// Faz o pedido; token expirado (401) é renovado uma vez.
  Future<(int, String)> _pedir(String metodo, String caminho,
      {String? corpo, String? tipo}) async {
    for (var tentativa = 0;; tentativa++) {
      final t = await token(tentativa > 0);
      final (status, texto) = await _http(metodo, caminho, t, corpo, tipo);
      if (status == 401 && tentativa == 0) continue;
      if (status == 401 || status == 403) {
        throw const ErroDoApp('o Google recusou o acesso ao Drive; '
            'saia e entre de novo na conta');
      }
      if (status < 200 || status > 299) {
        throw ErroDoApp('o Google Drive respondeu $status');
      }
      return (status, texto);
    }
  }

  Future<(int, String)> _http(String metodo, String caminho, String token,
      String? corpo, String? tipo) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await c.openUrl(metodo, Uri.parse('$base$caminho'));
      req.headers.set('Authorization', 'Bearer $token');
      if (corpo != null) {
        final bytes = utf8.encode(corpo);
        req.headers.set('Content-Type', tipo!);
        req.contentLength = bytes.length;
        req.add(bytes);
      }
      final resp = await req.close().timeout(const Duration(seconds: 30));
      final lido = BytesBuilder(copy: false);
      await for (final b in resp.timeout(const Duration(seconds: 30))) {
        lido.add(b);
        if (lido.length > limiteDrive) {
          throw const ErroDoApp('resposta grande demais do Google Drive');
        }
      }
      return (resp.statusCode, utf8.decode(lido.takeBytes(), allowMalformed: true));
    } on SocketException {
      throw const ErroDoApp('sem conexão com a internet');
    } on HttpException {
      throw const ErroDoApp('sem conexão com a internet');
    } on TimeoutException {
      throw const ErroDoApp('o Google Drive demorou demais para responder');
    } finally {
      c.close();
    }
  }
}
