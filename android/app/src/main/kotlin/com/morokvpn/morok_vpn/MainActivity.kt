package com.morokvpn.morok_vpn

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import java.security.MessageDigest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MOROK VPN — единственный нативный канал приложения.
 *
 * Здесь нет «своего» kill-switch: туннель поднимает плагин flutter_vless, и
 * его VpnService уже режет маршруты. Раньше в приложении жил сервис
 * com.morokvpn.morok_vpn.KillSwitchService, который
 *   1) не был объявлен в AndroidManifest (startForegroundService кидал
 *      ComponentNotFoundException, он проглатывался try/catch на Dart-стороне);
 *   2) в обработчике "enable" читал context из аргумента вызова
 *      (call.argument("context")), которого вызов не передавал, — то есть
 *      всегда завершался веткой "context не передан" и не делал ничего.
 * Итог: переключатель «Аварийное отключение» честно ничего не блокировал.
 *
 * Нативную самодеятельность убрали, вместо неё — честная точка входа в
 * системную панель «Постоянный VPN» (Android 12+), где пользователь включает
 * «Блокировать соединения без VPN». Это единственная гарантия утечек, которую
 * отдаёт ОС и которая переживает перезагрузку телефона.
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.morokvpn.app/vpn_settings"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Готово ли приложение отдать пользователя в системную
                    // панель: только Android 12+ (API 31) умеет
                    // «постоянный VPN + блокировка без туннеля».
                    "isSystemPanelAvailable" ->
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)

                    "openSystemPanel" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            // ACTION_VPN_SETTINGS — панель VPN в системных
                            // настройках; именно там лежит нужный переключатель.
                            startActivity(Intent(Settings.ACTION_VPN_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            // Роминовые сборки без стандартной панели —
                            // падаем в общий экран настроек.
                            try {
                                startActivity(Intent(Settings.ACTION_NETWORK_OPERATOR_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                result.success(true)
                            } catch (e2: Exception) {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    // Обезличенный признак устройства для защиты пробного
                    // периода от переустановки: сам идентификатор Android
                    // (ANDROID_ID) наружу не уходит — приложение считает от
                    // него SHA-256 с солью и отдаёт только хеш. Признак
                    // переживает удаление приложения (в отличие от ключей
                    // Keystore, которые стираются вместе с ним), а сброс
                    // телефона к заводским настройкам его меняет — это
                    // честная граница: новое «железо» считается новым.
                    "deviceFingerprint" -> {
                        try {
                            val androidId = Settings.Secure.getString(
                                contentResolver,
                                Settings.Secure.ANDROID_ID,
                            )
                            if (androidId.isNullOrEmpty()) {
                                result.success(null)
                            } else {
                                val digest = MessageDigest.getInstance("SHA-256")
                                val hash = digest.digest(
                                    "morok:v1:$androidId".toByteArray(Charsets.UTF_8),
                                )
                                result.success(hash.joinToString("") { "%02x".format(it) })
                            }
                        } catch (e: Exception) {
                            // Нет доступа к настройкам — не мешаем работе
                            // приложения: регистрация пройдёт без признака.
                            result.success(null)
                        }
                    }

                    // Спросить ОС, выдано ли приложению право поднимать VPN.
                    // Не запрашиваем его сами: запрос делает плагин туннеля.
                    "isPrepared" ->
                        result.success(VpnService.prepare(applicationContext) == null)

                    else -> result.notImplemented()
                }
            }
    }
}
