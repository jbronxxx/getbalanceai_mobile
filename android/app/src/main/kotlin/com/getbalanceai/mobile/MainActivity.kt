package com.getbalanceai.mobile

import android.os.Build
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Уровень API для DeviceCapabilityService: Platform.operatingSystemVersion
        // на Android — строка ядра Linux, версии Android в ней нет.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "androidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }
    }

    // Обход бага движка Flutter (ImeSyncDeferringInsetsCallback): пока идёт
    // анимация клавиатуры, отступы окна откладываются до её onEnd. Если
    // приложение уходит в фон посреди анимации, onEnd не приходит — Flutter
    // до следующего открытия клавиатуры считает, что она на экране, и шторки
    // висят над пустым местом. После возврата передаём FlutterView актуальные
    // отступы напрямую, минуя отложенный слушатель. Задержка — чтобы
    // системные анимации возврата успели закончиться.
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) return
        val flutterView = findViewById<View>(FLUTTER_VIEW_ID) ?: return
        flutterView.postDelayed({
            val insets = flutterView.rootWindowInsets ?: return@postDelayed
            flutterView.onApplyWindowInsets(insets)
        }, INSETS_SYNC_DELAY_MS)
    }

    private companion object {
        const val DEVICE_CHANNEL = "com.getbalanceai.mobile/device"
        const val INSETS_SYNC_DELAY_MS = 400L
    }
}
