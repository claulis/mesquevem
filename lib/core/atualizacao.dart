import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'ambiente.dart';
import 'erros.dart';

/// Número do build (o N de v1.0.0-N), passado pelo workflow de release com
/// --dart-define. 0 = build local/de desenvolvimento: nunca se oferece para
/// atualizar, porque não dá para saber se é mais novo ou mais velho.
const buildAtual = int.fromEnvironment('BUILD');

/// Versão instalada como aparece nas releases ("1.0.0-7"); vazia sem o define.
const versaoAtual = String.fromEnvironment('VERSAO');

const _api = 'https://api.github.com/repos/claulis/mesquevem/releases/latest';

class Release {
  final int build;
  final String tag, apk;

  /// SHA-256 do APK informado pelo GitHub, para conferir o download.
  final String? sha256;
  const Release(this.build, this.tag, this.apk, [this.sha256]);

  /// Lê a resposta de /releases/latest. Lança [FormatException] se a release
  /// não tiver número de build na tag ou não tiver APK.
  factory Release.deJson(Map<String, dynamic> j) {
    final tag = j['tag_name'] as String;
    // a tag vira nome de arquivo no download: nada de "/" ou ".."
    if (!tagValida(tag)) {
      throw FormatException('versão com nome inválido: $tag');
    }
    final build = int.tryParse(tag.split('-').last);
    if (build == null) throw FormatException('versão sem número: $tag');
    final apk = (j['assets'] as List)
        .cast<Map<String, dynamic>>()
        .where((a) => (a['name'] as String).endsWith('.apk'))
        .firstOrNull;
    if (apk == null) throw FormatException('a versão $tag não tem APK');
    final digest = apk['digest'] as String?;
    return Release(
        build,
        tag,
        apk['browser_download_url'] as String,
        digest != null && digest.startsWith('sha256:')
            ? digest.substring(7)
            : null);
  }
}

/// Só letras, números, "_", "." e "-" ("v1.0.0-14"), e não só pontos.
bool tagValida(String tag) =>
    RegExp(r'^[\w.\-]+$').hasMatch(tag) && !RegExp(r'^\.+$').hasMatch(tag);

bool temNova(Release r, {int atual = buildAtual}) =>
    atual > 0 && r.build > atual;

/// Última release publicada no GitHub.
Future<Release> ultimaRelease() => doAmbiente(() async {
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      try {
        final HttpClientResponse resp;
        final String corpo;
        try {
          final req = await c.getUrl(Uri.parse(_api));
          req.headers.set('Accept', 'application/vnd.github+json');
          resp = await req.close().timeout(const Duration(seconds: 30));
          corpo = await resp.transform(utf8.decoder).join();
        } on SocketException {
          throw const ErroDoApp('sem conexão com a internet');
        } on TimeoutException {
          throw const ErroDoApp('o GitHub demorou demais para responder');
        }
        if (resp.statusCode == 404) {
          throw const ErroDoApp('nenhuma versão publicada encontrada');
        }
        if (resp.statusCode != 200) {
          throw ErroDoApp('o GitHub respondeu ${resp.statusCode}');
        }
        return Release.deJson(jsonDecode(corpo) as Map<String, dynamic>);
      } finally {
        c.close();
      }
    }, 'não foi possível verificar');
