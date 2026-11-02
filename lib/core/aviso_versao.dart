import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'atualizacao.dart';

/// Aviso de versão nova: uma verificação em segundo plano a cada ~12h (o
/// Android decide o horário exato) que mostra uma notificação local.
// ponytail: notificação local por verificação periódica; push de verdade
// exigiria servidor (Firebase), só vale se precisar de aviso imediato.
final notificacoes = FlutterLocalNotificationsPlugin();

const _tarefa = 'verificar-versao';
const _jaAvisado = 'aviso_build_notificado';

Future<void> iniciarNotificacoes({void Function()? aoTocar}) =>
    notificacoes.initialize(
      settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (_) => aoTocar?.call(),
    );

/// Android 13+ pede permissão para notificar; nas versões antigas não faz nada.
Future<void> pedirPermissaoDeNotificar() async => notificacoes
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.requestNotificationsPermission();

/// Notifica uma vez por versão nova.
Future<void> verificarEAvisar() async {
  final r = await ultimaRelease();
  if (!temNova(r)) return;
  final p = await SharedPreferences.getInstance();
  // roda em segundo plano, num isolate com cache próprio: relê o disco para
  // não avisar de novo uma versão já avisada (nem deixar de avisar)
  await p.reload();
  if ((p.getInt(_jaAvisado) ?? 0) >= r.build) return;
  await notificacoes.show(
    id: 1,
    title: 'Mês que Vem: nova versão ${r.tag} 🎉',
    body: 'Toque para atualizar',
    notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('versao', 'Nova versão',
            channelDescription: 'Avisa quando sai uma versão nova do app')),
  );
  await p.setInt(_jaAvisado, r.build);
}

@pragma('vm:entry-point')
void verificarEmSegundoPlano() => Workmanager().executeTask((_, __) async {
      try {
        await iniciarNotificacoes();
        await verificarEAvisar();
      } catch (_) {
        // sem rede, GitHub fora etc.: tenta de novo no próximo ciclo
      }
      return true;
    });

Future<void> agendarVerificacao() async {
  await Workmanager().initialize(verificarEmSegundoPlano);
  await Workmanager().registerPeriodicTask(_tarefa, _tarefa,
      frequency: const Duration(hours: 12),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
}
