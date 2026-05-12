package com.example.mindful_diary

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.drawable.GradientDrawable
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class PlannerWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) updateWidget(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE_DONE) {
            val planId = intent.getStringExtra(EXTRA_PLAN_ID) ?: return
            togglePlanDone(context, planId)
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, PlannerWidget::class.java)
            )
            for (id in ids) updateWidget(context, mgr, id)
        }
    }

    companion object {
        const val ACTION_TOGGLE_DONE = "com.example.mindful_diary.TOGGLE_DONE"
        const val EXTRA_PLAN_ID = "plan_id"

        // Акцентные цвета — порядок совпадает с AppColors.accents в Dart
        private val ACCENT_COLORS = intArrayOf(
            0xFFE8927C.toInt(), // 0 — orange
            0xFF5B8CDB.toInt(), // 1 — blue
            0xFF9B59B6.toInt(), // 2 — purple
            0xFF2ECC71.toInt()  // 3 — green
        )

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.planner_widget)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // ── Акцентный цвет кнопки + ──────────────────────────────────
            val accentIndex = prefs.getInt("flutter.accentIndex", 0)
                .coerceIn(0, ACCENT_COLORS.lastIndex)
            val accentColor = ACCENT_COLORS[accentIndex]

            // Меняем цвет фона кнопки через setInt -> setColorFilter на ImageView
            // widget_add_bg это oval drawable — перекрашиваем через ImageView tint
            views.setInt(R.id.widget_add_btn, "setColorFilter", accentColor)

            // ── Планы на сегодня ──────────────────────────────────────────
            val plansJson = prefs.getString("flutter.plans", "{}") ?: "{}"
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

            val text = buildPlanText(plansJson, today)
            views.setTextViewText(R.id.widget_plans, text)

            // ── Тап на заголовок → открыть планировщик ───────────────────
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_planner", true)
            }
            views.setOnClickPendingIntent(
                R.id.widget_title,
                PendingIntent.getActivity(context, 1, openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )

            // ── Тап на + → открыть добавление плана ──────────────────────
            val addIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_planner", true)
                putExtra("add_plan", true)
            }
            views.setOnClickPendingIntent(
                R.id.widget_add_btn,
                PendingIntent.getActivity(context, 2, addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )

            // ── Тап на список → открыть планировщик ──────────────────────
            views.setOnClickPendingIntent(
                R.id.widget_plans,
                PendingIntent.getActivity(context, 3, openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun buildPlanText(plansJson: String, today: String): String {
            return try {
                val allPlans = JSONObject(plansJson)
                val todayPlans = allPlans.optJSONArray(today)

                if (todayPlans == null || todayPlans.length() == 0) {
                    "Нет планов на сегодня\nНажми + чтобы добавить"
                } else {
                    val sb = StringBuilder()
                    for (i in 0 until todayPlans.length()) {
                        val plan = todayPlans.getJSONObject(i)
                        val text = plan.optString("text", "")
                        val time = if (plan.isNull("time")) "" else plan.optString("time", "")
                        val done = plan.optBoolean("done", false)

                        val check = if (done) "✓" else "•"
                        val timePart = if (time.isNotEmpty()) "$time  " else ""
                        sb.append("$check  $timePart$text\n")
                    }
                    sb.toString().trimEnd()
                }
            } catch (e: Exception) {
                "Нет планов на сегодня"
            }
        }

        private fun togglePlanDone(context: Context, planId: String) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val plansJson = prefs.getString("flutter.plans", "{}") ?: "{}"
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            try {
                val allPlans = JSONObject(plansJson)
                val todayPlans = allPlans.optJSONArray(today) ?: return
                for (i in 0 until todayPlans.length()) {
                    val plan = todayPlans.getJSONObject(i)
                    if (plan.optString("id") == planId) {
                        plan.put("done", !plan.optBoolean("done", false))
                        break
                    }
                }
                allPlans.put(today, todayPlans)
                prefs.edit().putString("flutter.plans", allPlans.toString()).apply()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
