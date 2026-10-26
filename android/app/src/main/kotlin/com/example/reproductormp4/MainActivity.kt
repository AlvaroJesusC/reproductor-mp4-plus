package com.example.reproductormp4

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CANAL_PIP = "com.example.reproductormp4/pip"
    private var canalMetodos: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canalMetodos = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_PIP)
        canalMetodos?.setMethodCallHandler { call, result ->
            when (call.method) {
                "esSoportado" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE))
                    } else {
                        result.success(false)
                    }
                }
                "activarPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val params = PictureInPictureParams.Builder()
                                .setAspectRatio(Rational(16, 9))
                                .build()
                            val exito = enterPictureInPictureMode(params)
                            result.success(exito)
                        } catch (e: Exception) {
                            result.error("ERROR_PIP", e.localizedMessage, null)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "estaEnPip" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(isInPictureInPictureMode)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        canalMetodos?.invokeMethod("alCambiarEstadoPip", isInPictureInPictureMode)
    }
}
