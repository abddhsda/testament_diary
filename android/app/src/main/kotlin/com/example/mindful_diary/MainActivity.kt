package com.example.mindful_diary

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.mindful_diary/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val appWidgetManager = AppWidgetManager.getInstance(this)
                val ids = appWidgetManager.getAppWidgetIds(
                    ComponentName(this, PlannerWidget::class.java)
                )
                for (id in ids) {
                    PlannerWidget.updateWidget(this, appWidgetManager, id)
                }
                result.success(null)
            } else if (call.method == "checkOpenPlanner") {
                val open = intent.getBooleanExtra("open_planner", false)
                if (open) intent.removeExtra("open_planner")
                result.success(open)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.mindful_diary/alarm").setMethodCallHandler { call, result ->
            if (call.method == "setAlarm") {
                val hour = call.argument<Int>("hour") ?: 0
                val minute = call.argument<Int>("minute") ?: 0
                val message = call.argument<String>("message") ?: ""
                val alarmIntent = android.content.Intent(android.provider.AlarmClock.ACTION_SET_ALARM).apply {
                    putExtra(android.provider.AlarmClock.EXTRA_HOUR, hour)
                    putExtra(android.provider.AlarmClock.EXTRA_MINUTES, minute)
                    putExtra(android.provider.AlarmClock.EXTRA_MESSAGE, message)
                    putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, false)
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(alarmIntent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}