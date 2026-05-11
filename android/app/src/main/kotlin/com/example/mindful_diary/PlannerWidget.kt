package com.example.mindful_diary

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class PlannerWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.planner_widget)

            val prefs: SharedPreferences = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE
            )

            val plansJson = prefs.getString("flutter.plans", "{}") ?: "{}"
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

            try {
                val allPlans = JSONObject(plansJson)
                val todayPlans = allPlans.optJSONArray(today)

                if (todayPlans == null || todayPlans.length() == 0) {
                    views.setTextViewText(R.id.widget_plans, "Нет планов на сегодня")
                } else {
                    val sb = StringBuilder()
                    for (i in 0 until todayPlans.length()) {
                        val plan = todayPlans.getJSONObject(i)
                        val text = plan.optString("text", "")
                        val time = if (plan.isNull("time")) "" else plan.optString("time", "")
                        val done = plan.optBoolean("done", false)
                        val prefix = if (done) "✓ " else "• "
                        val timePart = if (time.isNotEmpty()) "$time " else ""
                        sb.appendLine("$prefix$timePart$text")
                    }
                    views.setTextViewText(R.id.widget_plans, sb.toString().trimEnd())
                }
            } catch (e: Exception) {
                views.setTextViewText(R.id.widget_plans, "Нет планов на сегодня")
            }

            // Тап на виджет открывает приложение
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val launchPi = PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_title, launchPi)
        }
    }
}