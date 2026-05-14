package com.example.mindful_diary

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent
import android.net.Uri
import android.os.Handler
import android.os.Looper
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

        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, PlannerWidget::class.java))
            for (id in ids) updateWidget(context, mgr, id)
            return
        }

        if (intent.action == ACTION_TOGGLE_DONE) {
            val planId = intent.getStringExtra(EXTRA_PLAN_ID) ?: return
            val wasDone = togglePlanDone(context, planId)
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                android.content.ComponentName(context, PlannerWidget::class.java))

            if (!wasDone) {
                Handler(Looper.getMainLooper()).postDelayed({
                    addToHidden(context, planId)
                    for (id in ids) {
                        mgr.notifyAppWidgetViewDataChanged(id, R.id.widget_plans_list)
                        updateWidget(context, mgr, id)
                    }
                }, 20_000L)
            }

            for (id in ids) {
                mgr.notifyAppWidgetViewDataChanged(id, R.id.widget_plans_list)
                updateWidget(context, mgr, id)
            }
        }
    }

    companion object {
        const val ACTION_TOGGLE_DONE = "com.example.mindful_diary.TOGGLE_DONE"
        const val EXTRA_PLAN_ID = "plan_id"

        private val ACCENT_COLORS = intArrayOf(
            0xFFE8927C.toInt(),
            0xFF5B8CDB.toInt(),
            0xFF9B59B6.toInt(),
            0xFF2ECC71.toInt()
        )

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.planner_widget)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // ── Акцентный цвет ────────────────────────────────────────────
            // Flutter сохраняет Int как Long в SharedPreferences
            val accentIndex = try {
                val v = prefs.getLong("flutter.accentIndex", -1L)
                if (v >= 0L) v.toInt() else prefs.getInt("accentIndex", 0)
            } catch (e: Exception) { 0 }.coerceIn(0, ACCENT_COLORS.lastIndex)

            views.setInt(R.id.widget_add_bg, "setColorFilter", ACCENT_COLORS[accentIndex])
            views.setInt(R.id.widget_add_btn, "setColorFilter", 0xFFFFFFFF.toInt())

            // ── Данные планов ─────────────────────────────────────────────
            val plansJson = prefs.getString("flutter.plans", null)
                ?: prefs.getString("plans", "{}") ?: "{}"
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            val hiddenIds = getHiddenIds(prefs, today)
            val hasVisible = hasVisiblePlans(plansJson, today, hiddenIds)

            // ── Видимость списка / заглушки ───────────────────────────────
            if (hasVisible) {
                views.setViewVisibility(R.id.widget_plans_list, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_plans_list, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            }

            // ── RemoteViewsService адаптер ────────────────────────────────
            val serviceIntent = Intent(context, PlannerWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                // data должен быть уникальным для каждого виджета
                data = Uri.parse("widget://$appWidgetId")
            }
            views.setRemoteAdapter(R.id.widget_plans_list, serviceIntent)
            views.setEmptyView(R.id.widget_plans_list, R.id.widget_empty)

            // ── PendingIntent шаблон для toggle done ──────────────────────
            val toggleIntent = Intent(context, PlannerWidget::class.java).apply {
                action = ACTION_TOGGLE_DONE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val togglePi = PendingIntent.getBroadcast(
                context, appWidgetId, toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_plans_list, togglePi)

            // ── Тап на заголовок / заглушку → планировщик ────────────────
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("open_planner", true)
            }
            val openPi = PendingIntent.getActivity(
                context, 1, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_title, openPi)
            views.setOnClickPendingIntent(R.id.widget_empty, openPi)

            // ── Тап на + → AddPlanActivity ────────────────────────────────
            val addIntent = Intent(context, AddPlanActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val addPi = PendingIntent.getActivity(
                context, 2, addIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_add_btn_frame, addPi)

            // ── Применяем и сразу уведомляем ListView об обновлении ───────
            appWidgetManager.updateAppWidget(appWidgetId, views)
            // Это ключевая строка — без неё RemoteViewsService может не вызваться
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_plans_list)
        }

        private fun hasVisiblePlans(
            plansJson: String, today: String, hiddenIds: Set<String>
        ): Boolean {
            return try {
                val arr = JSONObject(plansJson).optJSONArray(today) ?: return false
                for (i in 0 until arr.length()) {
                    val plan = arr.getJSONObject(i)
                    val id = plan.optString("id")
                    val done = plan.optBoolean("done", false)
                    if (!done || !hiddenIds.contains(id)) return true
                }
                false
            } catch (e: Exception) { false }
        }

        fun togglePlanDone(context: Context, planId: String): Boolean {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            var wasDone = false
            for (key in listOf("flutter.plans", "plans")) {
                val json = prefs.getString(key, null) ?: continue
                try {
                    val allPlans = JSONObject(json)
                    val todayPlans = allPlans.optJSONArray(today) ?: continue
                    for (i in 0 until todayPlans.length()) {
                        val plan = todayPlans.getJSONObject(i)
                        if (plan.optString("id") == planId) {
                            wasDone = plan.optBoolean("done", false)
                            plan.put("done", !wasDone)
                            allPlans.put(today, todayPlans)
                            prefs.edit().putString(key, allPlans.toString()).apply()
                            break
                        }
                    }
                } catch (e: Exception) { e.printStackTrace() }
            }
            return wasDone
        }

        private fun getHiddenIds(
            prefs: android.content.SharedPreferences, today: String
        ): Set<String> = try {
            prefs.getString("widget_hide_done_$today", "")!!
                .split(",").filter { it.isNotEmpty() }.toSet()
        } catch (e: Exception) { emptySet() }

        private fun addToHidden(context: Context, planId: String) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
            val key = "widget_hide_done_$today"
            val ids = (prefs.getString(key, "") ?: "")
                .split(",").filter { it.isNotEmpty() }.toMutableSet()
            ids.add(planId)
            prefs.edit().putString(key, ids.joinToString(",")).apply()
        }
    }
}
