package com.lifestatistics.life_statistics

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class MainActivity : FlutterActivity() {
    companion object {
        const val ENGINE_ID = "life_statistics_engine"
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        var engine = FlutterEngineCache.getInstance().get(ENGINE_ID)
        if (engine == null) {
            engine = FlutterEngine(context.applicationContext)
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        }
        return engine
    }

    override fun shouldDestroyEngineWithHost(): Boolean {
        // Keeps the Dart environment and stream listeners running in the background 24/7!
        return false
    }
}
