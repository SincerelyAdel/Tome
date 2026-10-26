package com.sincerelyadel.tome

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens Android's share sheet (Quick Share, Bluetooth, ...) for a file.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tome/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "openRun") {
                    openRun(call, result)
                    return@setMethodCallHandler
                }
                if (call.method != "shareFile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val file = File(call.argument<String>("path")!!)
                    val uri = FileProvider.getUriForFile(this, "$packageName.share", file)
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = call.argument<String>("mime") ?: "*/*"
                        putExtra(Intent.EXTRA_STREAM, uri)
                        clipData = ClipData.newRawUri(file.name, uri)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(Intent.createChooser(send, call.argument<String>("title")))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("share_failed", e.message, null)
                }
            }
    }

    // Opens a zipped uvm-debugger run in whichever app accepts its type
    // (the UVM viewer). Goes by type, not package, so the viewer can be
    // renamed. Extras say where the run came from.
    private fun openRun(call: MethodCall, result: MethodChannel.Result) {
        try {
            val file = File(call.argument<String>("path")!!)
            val uri = FileProvider.getUriForFile(this, "$packageName.share", file)
            val view = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, call.argument<String>("mime"))
                call.argument<Map<String, String>>("extras")?.forEach { (k, v) ->
                    putExtra("uvmdbg.$k", v)
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(view)
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("no_viewer", e.message, null)
        } catch (e: Exception) {
            result.error("open_failed", e.message, null)
        }
    }
}
