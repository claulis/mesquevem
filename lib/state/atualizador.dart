import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../core/ambiente.dart';
import '../core/atualizacao.dart';
import '../core/erros.dart';

enum Fase {
  ocioso,
  verificando,
  baixando,
  semConexao,
  conferindo,
  pronto,
  erro
}

/// Abre o instalador do Android com o APK baixado (MainActivity.kt). Devolve
/// "permissao" se o app ainda não pode instalar (o Android abriu o ajuste).
typedef Instalar = Future<String> Function(String caminho);

const _canal = MethodChannel('mesquevem/instalar');
Future<String> instalarComSistema(String caminho) async =>
    await _canal.invokeMethod<String>('instalar', {'caminho': caminho}) ?? 'ok';

/// Queda de rede ou falha passageira do servidor: espera e tenta de novo.
class _Queda implements Exception {
  final Object causa;
  _Queda(this.causa);
}

/// Baixa e instala a versão nova. Vive no app inteiro (não na tela): sair da
/// tela e voltar mostra o mesmo progresso.
///
/// O download é retomável: os bytes vão para `<tag>.apk.parte` e o "ponto
/// salvo" (tamanho total, ETag) para `<tag>.json`. Se a conexão cai, tenta
/// de novo com `Range: bytes=N-` + `If-Range` (o servidor só continua se o
/// arquivo for o mesmo); se o app é fechado, [retomarSalvo] continua na
/// próxima abertura. No fim confere tamanho e SHA-256 antes de instalar.
class Atualizador extends ChangeNotifier {
  final Future<Release> Function() _verificar;
  final Future<Directory> Function() _pasta;
  final Instalar _instalar;
  final int atual;
  final String versao;

  /// Esperas entre tentativas sem conexão (a última se repete).
  final List<Duration> esperas;

  /// Sem nenhum byte por este tempo, a conexão conta como caída.
  final Duration semDados;

  /// Recusa endereço sem https (inclusive em redirect), para ninguém no
  /// caminho da rede trocar o APK. Só os testes, com servidor local, desligam.
  final bool exigirHttps;

  Atualizador({
    Future<Release> Function() verificar = ultimaRelease,
    Future<Directory> Function() pasta = getApplicationSupportDirectory,
    Instalar instalar = instalarComSistema,
    this.atual = buildAtual,
    this.versao = versaoAtual,
    this.esperas = const [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 30),
    ],
    this.semDados = const Duration(seconds: 20),
    this.exigirHttps = true,
  })  : _verificar = verificar,
        _pasta = pasta,
        _instalar = instalar;

  Fase fase = Fase.ocioso;
  Release? release;
  int recebidos = 0, total = 0;

  /// Segundos até a próxima tentativa, em [Fase.semConexao].
  int tentarEm = 0;
  String? erro;

  /// Recado depois de chamar o instalador (ex.: falta permissão).
  String? aviso;

  bool get rodando => _rodando;
  bool temNovaVersao(Release r) => temNova(r, atual: atual);

  /// Já há bytes baixados (o botão vira "Continuar").
  bool get temPontoSalvo => recebidos > 0 && fase != Fase.pronto;

  bool _rodando = false, _cancelado = false;
  HttpClient? _cliente;
  Completer<void>? _espera;
  File? _apk;
  DateTime _ultimoAviso = DateTime(0);

  void _mudar(Fase f, {String? erro}) {
    fase = f;
    this.erro = erro;
    notifyListeners();
  }

  /// Só consulta a última versão (botão "Verificar atualização").
  Future<void> verificar() async {
    if (_rodando) return;
    _mudar(Fase.verificando);
    try {
      release = await _verificar();
      _mudar(Fase.ocioso);
    } catch (e) {
      _mudar(Fase.erro, erro: mensagem(e));
    }
  }

  /// "Atualizar agora": confere a conexão consultando a última versão e, se
  /// for mais nova, baixa (continuando de um ponto salvo, se houver).
  Future<void> atualizar() async {
    if (_rodando) return;
    _mudar(Fase.verificando);
    final Release r;
    try {
      r = await _verificar();
    } catch (e) {
      return _mudar(Fase.erro,
          erro: 'Sem conexão: conecte-se e tente de novo (${mensagem(e)})');
    }
    release = r;
    if (!temNovaVersao(r)) return _mudar(Fase.ocioso);
    await _baixar(r);
  }

  /// Na abertura do app: download interrompido de uma versão mais nova
  /// continua sozinho; restos de versões já instaladas são apagados.
  Future<void> retomarSalvo() async {
    if (_rodando) return;
    try {
      final dir = await _dir();
      for (final f in dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final r = Release(m['build'], m['tag'], m['apk'], m['sha256']);
        // a tag vira nome de arquivo: ponto salvo adulterado é ignorado
        if (!tagValida(r.tag) || !temNovaVersao(r)) continue;
        release = r;
        final pronto = File(_caminho(dir, r, '.apk'));
        if (await pronto.exists()) {
          _apk = pronto;
          return _mudar(Fase.pronto);
        }
        return await _baixar(r);
      }
      // nada a retomar: limpa o que sobrou (versões já instaladas)
      for (final f in dir.listSync()) {
        await f.delete(recursive: true);
      }
    } catch (_) {
      // sem ponto salvo legível: o usuário pode começar de novo pela tela
    }
  }

  /// Para e apaga o que foi baixado.
  Future<void> cancelar() async {
    // APK já baixado e conferido (abrindo o instalador): nada a cancelar
    if (!_rodando || fase == Fase.pronto) return;
    _cancelado = true;
    _cliente?.close(force: true);
    if (!(_espera?.isCompleted ?? true)) _espera!.complete();
  }

  /// Abre o instalador de novo (ex.: depois de dar a permissão).
  Future<void> instalar() async {
    final apk = _apk;
    if (apk == null) return;
    try {
      aviso = await _instalar(apk.path) == 'permissao'
          ? 'Permita "instalar apps desta fonte" para o Mês que Vem e toque '
              'em Instalar.'
          : 'Abrindo o instalador: toque em "Atualizar" para concluir.';
    } catch (e) {
      aviso = 'Não foi possível abrir o instalador (${mensagem(e)}).';
    }
    notifyListeners();
  }

  Future<Directory> _dir() async =>
      Directory('${(await _pasta()).path}/atualizacao').create(recursive: true);

  static String _caminho(Directory d, Release r, String ext) =>
      '${d.path}/mesquevem-${r.tag}$ext';

  Future<void> _baixar(Release r) async {
    _rodando = true;
    _cancelado = false;
    aviso = null;
    var arquivos = <File>[]; // parte e meta, para o cancelar apagar
    var tentativa = 0, corrompidos = 0;
    // tudo dentro do try: se preparar a pasta falhar (disco cheio, sem
    // permissão), o finally ainda libera _rodando e a tela não fica travada
    try {
      // sem o SHA-256 informado pelo GitHub não há como conferir o arquivo:
      // não baixa (a página da release continua disponível pelo navegador)
      if (r.sha256 == null) {
        return _mudar(Fase.erro,
            erro: 'Esta versão não informa o código de integridade (SHA-256). '
                'Atualize pela página da versão no GitHub.');
      }
      final dir = await _dir();
      final parte = File(_caminho(dir, r, '.apk.parte'));
      final meta = File(_caminho(dir, r, '.json'));
      arquivos = [parte, meta];
      // ponto salvo de outra versão não serve mais
      for (final f in dir.listSync()) {
        if (!f.path.contains('mesquevem-${r.tag}.')) {
          await f.delete(recursive: true);
        }
      }
      while (!_cancelado) {
        try {
          final m = await _baixarTrecho(r, parte, meta, () => tentativa = 0);
          _mudar(Fase.conferindo);
          // tamanho desconhecido (-1: servidor sem Content-Length) não é
          // comparado; o SHA-256, obrigatório, garante a integridade
          final tamanho = m['total'] as int;
          final ok = (tamanho < 0 || await parte.length() == tamanho) &&
              (await sha256.bind(parte.openRead()).first).toString() ==
                  r.sha256;
          if (!ok) {
            await _apagar([parte, meta]);
            if (++corrompidos > 1) {
              return _mudar(Fase.erro,
                  erro: 'O arquivo baixado veio corrompido duas vezes. '
                      'Tente mais tarde.');
            }
            continue;
          }
          _apk = await parte.rename(_caminho(dir, r, '.apk'));
          _mudar(Fase.pronto);
          return await instalar();
        } on _Queda {
          if (_cancelado) break;
          final espera = esperas[min(tentativa++, esperas.length - 1)];
          tentarEm = espera.inSeconds;
          _mudar(Fase.semConexao);
          _espera = Completer();
          final t = Timer(espera, _espera!.complete);
          await _espera!.future;
          t.cancel();
        } on FileSystemException catch (e) {
          return _mudar(Fase.erro,
              erro: 'Não foi possível gravar o download (${e.message}).');
        } catch (e) {
          return _mudar(Fase.erro, erro: mensagem(e));
        }
      }
    } on FileSystemException catch (e) {
      _mudar(Fase.erro,
          erro: 'Não foi possível preparar o download (${e.message}).');
    } finally {
      _rodando = false;
      _cliente = null;
      if (_cancelado) {
        await _apagar(arquivos);
        recebidos = total = 0;
        _mudar(Fase.ocioso);
      }
    }
  }

  static Future<void> _apagar(List<File> arquivos) async {
    for (final f in arquivos) {
      try {
        await f.delete();
      } on PathNotFoundException {
        // já não existe
      }
    }
  }

  Future<Map<String, dynamic>> _lerMeta(File meta, Release r) async {
    try {
      final m = jsonDecode(await meta.readAsString()) as Map<String, dynamic>;
      if (m['tag'] == r.tag) return m;
    } catch (_) {
      // sem ponto salvo
    }
    return {
      'tag': r.tag,
      'build': r.build,
      'apk': r.apk,
      'sha256': r.sha256,
      'total': 0,
      'etag': null,
    };
  }

  /// Baixa do ponto salvo (relido do disco a cada tentativa) até o fim.
  /// Lança [_Queda] se a conexão cair.
  Future<Map<String, dynamic>> _baixarTrecho(
      Release r, File parte, File meta, void Function() progrediu) async {
    var m = await _lerMeta(meta, r);
    final c = _cliente = HttpClient()..connectionTimeout = semDados;
    try {
      var inicio = await parte.exists() ? await parte.length() : 0;
      final totalSalvo = m['total'] as int;
      // ponto salvo incoerente (parte maior que o arquivo): recomeça
      if (inicio > 0 && (totalSalvo == 0 || inicio > totalSalvo)) inicio = 0;
      // sem ETag não há If-Range: o servidor continuaria mesmo que o arquivo
      // tivesse mudado, juntando pedaços de dois APKs. Recomeça do zero.
      if (inicio > 0 && m['etag'] == null) inicio = 0;

      // redirect manual: a URL assinada do CDN expira, então é renovada a
      // cada tentativa, e o Range vai junto
      var url = Uri.parse(r.apk);
      HttpClientResponse resp;
      for (var i = 0;; i++) {
        if (exigirHttps && url.scheme != 'https') {
          throw const ErroDoApp('download recusado: o endereço não usa https');
        }
        final req = await c.getUrl(url);
        req.followRedirects = false;
        if (inicio > 0) {
          req.headers.set('Range', 'bytes=$inicio-');
          if (m['etag'] != null) req.headers.set('If-Range', m['etag']);
        }
        resp = await req.close().timeout(semDados);
        if (resp.isRedirect && i < 5) {
          await resp.drain<void>();
          final destino = resp.headers.value('location');
          if (destino == null) {
            throw const ErroDoApp('o servidor redirecionou sem destino');
          }
          url = url.resolve(destino);
          continue;
        }
        break;
      }

      switch (resp.statusCode) {
        case 206:
          // Content-Range: bytes 100-999/1000
          final cr = resp.headers.value('content-range') ?? '';
          m = {...m, 'total': int.tryParse(cr.split('/').last) ?? totalSalvo};
        case 200:
          // arquivo novo ou mudou no servidor (If-Range não bateu): do zero
          inicio = 0;
          m = {
            ...m,
            'total': resp.contentLength,
            'etag': resp.headers.value('etag'),
          };
        case 416 when inicio == totalSalvo:
          await resp.drain<void>();
          return m; // já estava completo
        case 416:
          await resp.drain<void>();
          await parte.delete();
          throw _Queda('ponto salvo inválido');
        case >= 500:
          await resp.drain<void>();
          throw _Queda('servidor respondeu ${resp.statusCode}');
        default:
          await resp.drain<void>();
          throw ErroDoApp('o download respondeu ${resp.statusCode}');
      }
      await meta.writeAsString(jsonEncode(m), flush: true);
      total = m['total'];
      recebidos = inicio;
      _mudar(Fase.baixando);

      final saida =
          parte.openWrite(mode: inicio == 0 ? FileMode.write : FileMode.append);
      try {
        await for (final bloco in resp.timeout(semDados)) {
          saida.add(bloco);
          recebidos += bloco.length;
          progrediu();
          final agora = DateTime.now();
          if (agora.difference(_ultimoAviso).inMilliseconds > 250) {
            _ultimoAviso = agora;
            notifyListeners();
          }
        }
      } finally {
        await saida.close();
      }
      notifyListeners();
      if (await parte.length() < total) {
        throw _Queda('conexão encerrada antes do fim');
      }
      return m;
    } on SocketException catch (e) {
      throw _Queda(e);
    } on HttpException catch (e) {
      throw _Queda(e);
    } on TimeoutException catch (e) {
      throw _Queda(e);
    } on TlsException catch (e) {
      throw _Queda(e);
    } finally {
      c.close(force: true);
    }
  }
}
