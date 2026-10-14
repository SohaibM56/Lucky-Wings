package com.robinson.luckywings

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity(), CoroutineScope by MainScope() {
    private val CHANNEL = "com.robinson.luckywings/play_audio"

    private lateinit var activityContext: Context

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activityContext = this
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "playAudio") {
                call.argument<String>("path")?.let { playAudio(it) }
                result.success(true)
            } else if (call.method == "ratingUs") {
                ratingUs(result)
            }
        }
    }

    private fun playAudio(path: String) {
        launch(Dispatchers.Default) {
            try {
                val mediaPlayer = MediaPlayer()
                mediaPlayer.setDataSource(
                    activityContext,
                    Uri.parse("android.resource://${activityContext.packageName}/raw/$path")
                )
                mediaPlayer.setOnCompletionListener {
                    mediaPlayer.release()
                    this.cancel()
                }
                mediaPlayer.setOnPreparedListener {
                    it.start()
                }
                mediaPlayer.prepareAsync()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun ratingUs(result: MethodChannel.Result) {
        val manager = ReviewManagerFactory.create(context)
        val request = manager.requestReviewFlow()
        request.addOnCompleteListener {
            if (request.isSuccessful) {
                val reviewInfo = request.result
                if (reviewInfo != null) {
                    val flow = manager.launchReviewFlow(activity, reviewInfo)
                    flow.addOnCompleteListener { _ ->
                        // The flow has finished. The API does not indicate whether the user
                        // reviewed or not, or even whether the review dialog was shown. Thus, no
                        // matter the result, we continue our app flow.
                        result.success(true)
                    }
                }else{
                    result.success(false)
                }
            }else{
                result.success(false)
            }
        }
    }
}