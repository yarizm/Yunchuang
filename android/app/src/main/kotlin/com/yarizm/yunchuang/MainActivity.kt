package com.yarizm.yunchuang

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 冷启动就是被「打开方式」或分享拉起来的，先把文件收下。
        SharedFileReceiver.handleIntent(this, intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // launchMode 是 singleTop，应用已在前台时再分享一本书走这里。
        setIntent(intent)
        SharedFileReceiver.handleIntent(this, intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARED_FILES_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePending" -> result.success(SharedFileReceiver.consumePending())
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BRIGHTNESS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBrightness" -> {
                    val windowBrightness = window.attributes.screenBrightness
                    if (windowBrightness >= 0f) {
                        result.success(windowBrightness.toDouble())
                    } else {
                        val systemBrightness = try {
                            Settings.System.getInt(
                                contentResolver,
                                Settings.System.SCREEN_BRIGHTNESS,
                            ) / 255.0
                        } catch (_: Settings.SettingNotFoundException) {
                            0.5
                        }
                        result.success(systemBrightness.coerceIn(0.05, 1.0))
                    }
                }

                "setBrightness" -> {
                    val value = call.argument<Number>("value")?.toFloat()
                    if (value == null) {
                        result.error("invalid_brightness", "Missing brightness value.", null)
                        return@setMethodCallHandler
                    }
                    val attributes = window.attributes
                    attributes.screenBrightness = value.coerceIn(0.05f, 1.0f)
                    window.attributes = attributes
                    result.success(null)
                }

                "resetBrightness" -> {
                    val attributes = window.attributes
                    attributes.screenBrightness =
                        android.view.WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                    window.attributes = attributes
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val BRIGHTNESS_CHANNEL = "yunchuang/screen_brightness"
        private const val SHARED_FILES_CHANNEL = "yunchuang/shared_files"
    }
}
