package com.example.compras

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // Config → Atualizar: abre o instalador do Android com o APK já baixado
    // e conferido pelo app (lib/state/atualizador.dart).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mesquevem/instalar")
            .setMethodCallHandler { call, result ->
                if (call.method != "instalar") return@setMethodCallHandler result.notImplemented()
                try {
                    if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                        )
                        return@setMethodCallHandler result.success("permissao")
                    }
                    val apk = File(call.argument<String>("caminho")!!)
                    val uri = FileProvider.getUriForFile(this, "$packageName.instalador", apk)
                    startActivity(
                        Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success("ok")
                } catch (e: Exception) {
                    result.error("instalar", e.message, null)
                }
            }
    }
}
