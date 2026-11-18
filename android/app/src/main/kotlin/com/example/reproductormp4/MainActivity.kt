package com.example.reproductormp4

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CANAL_PIP = "com.example.reproductormp4/pip"
    private val CANAL_METADATOS = "com.example.reproductormp4/metadatos"
    private var canalMetodos: MethodChannel? = null
    private var canalMetadatos: MethodChannel? = null
    private val ejecutorMetadatos: ExecutorService = Executors.newFixedThreadPool(3)
    private val manejadorPrincipal = Handler(Looper.getMainLooper())
    private var autoPipHabilitado = false
    private var aspectNumerator = 16
    private var aspectDenominator = 9

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
                    result.success(entrarEnPip())
                }
                "configurarAutoPip" -> {
                    val habilitado = call.argument<Boolean>("habilitado") ?: false
                    val ancho = call.argument<Int>("ancho") ?: 16
                    val alto = call.argument<Int>("alto") ?: 9
                    autoPipHabilitado = habilitado
                    actualizarRelacionAspecto(ancho, alto)
                    actualizarAutoPipParams()
                    result.success(true)
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

        canalMetadatos = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_METADATOS)
        canalMetadatos?.setMethodCallHandler { call, result ->
            when (call.method) {
                "obtenerDuracionMs" -> {
                    val ruta = call.argument<String>("ruta")
                    if (ruta.isNullOrEmpty() || ejecutorMetadatos.isShutdown) {
                        result.success(0L)
                        return@setMethodCallHandler
                    }
                    try {
                        ejecutorMetadatos.execute {
                            val duracionMs = extraerDuracionMs(ruta)
                            manejadorPrincipal.post {
                                try {
                                    result.success(duracionMs)
                                } catch (_: Exception) {}
                            }
                        }
                    } catch (_: Exception) {
                        result.success(0L)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun extraerDuracionMs(ruta: String): Long {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(ruta)
            val durStr = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            durStr?.toLongOrNull()?.coerceAtLeast(0L) ?: 0L
        } catch (_: Exception) {
            0L
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {}
        }
    }

    private fun actualizarRelacionAspecto(ancho: Int, alto: Int) {
        if (ancho > 0 && alto > 0) {
            val ratio = ancho.toFloat() / alto.toFloat()
            // Android PiP requires aspect ratio between 1:2.39 (0.4184f) and 2.39:1 (2.39f)
            if (ratio in 0.42f..2.38f) {
                aspectNumerator = ancho
                aspectDenominator = alto
                return
            }
        }
        aspectNumerator = 16
        aspectDenominator = 9
    }

    private fun entrarEnPip(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                if (!packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                    return false
                }
                val builder = PictureInPictureParams.Builder()
                    .setAspectRatio(Rational(aspectNumerator, aspectDenominator))
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    builder.setAutoEnterEnabled(autoPipHabilitado)
                }
                return enterPictureInPictureMode(builder.build())
            } catch (e: Exception) {
                return false
            }
        }
        return false
    }

    private fun actualizarAutoPipParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                if (packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                    val builder = PictureInPictureParams.Builder()
                        .setAspectRatio(Rational(aspectNumerator, aspectDenominator))
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        builder.setAutoEnterEnabled(autoPipHabilitado)
                    }
                    setPictureInPictureParams(builder.build())
                }
            } catch (_: Exception) {}
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Si el usuario presiona Home o se sale de la app mientras se reproduce un video,
        // entra automáticamente en modo Picture-in-Picture estilo YouTube
        if (autoPipHabilitado && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !isInPictureInPictureMode) {
            entrarEnPip()
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        canalMetodos?.invokeMethod("alCambiarEstadoPip", isInPictureInPictureMode)
        if (!isInPictureInPictureMode && isFinishing) {
            canalMetodos?.invokeMethod("alCerrarPipNativo", null)
        }
    }

    override fun onStop() {
        super.onStop()
        if (isFinishing) {
            canalMetodos?.invokeMethod("alCerrarPipNativo", null)
        }
    }

    override fun onDestroy() {
        ejecutorMetadatos.shutdownNow()
        super.onDestroy()
    }
}
