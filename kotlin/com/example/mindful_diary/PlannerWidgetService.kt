package com.example.mindful_diary

import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class PlannerWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return PlannerRemoteViewsFactory(applicationContext)
    }
}

class PlannerRemoteViewsFactory(private val context: Context) :
    RemoteViewsService.RemoteViewsFactory {

    data class PlanItem(
        val id: String,
        val text: String,
        val time: String?,   // null = без времени
        val done: Boolean
    )

    // Только невыполненные + временно показываем done (для 20-сек анимации)
    private var plans: List<PlanItem> = emptyList()

    override fun onCreate() { loadPlans() }
    override fun onDataSetChanged() { loadPlans() }
    override fun onDestroy() {}

    private fun loadPlans() {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val plansJson = prefs.getString("flutter.plans", null)
            ?: prefs.getString("plans", "{}") ?: "{}"

        val hideDoneKey = "widget_hide_done_$today"
        // Список id планов которые уже скрыты (прошло >20 сек после выполнения)
        val hiddenIds = try {
            prefs.getString(hideDoneKey, "")!!
                .split(",").filter { it.isNotEmpty() }.toSet()
        } catch (e: Exception) { emptySet() }

        val all = try {
            val allPlans = JSONObject(plansJson)
            val todayArr = allPlans.optJSONArray(today)
            if (todayArr == null) emptyList()
            else (0 until todayArr.length()).map { i ->
                val obj = todayArr.getJSONObject(i)
                PlanItem(
                    id   = obj.optString("id", i.toString()),
                    text = obj.optString("text", ""),
                    time = if (obj.isNull("time")) null else obj.optString("time").ifEmpty { null },
                    done = obj.optBoolean("done", false)
                )
            }
        } catch (e: Exception) { emptyList() }

        // Фильтр: скрываем выполненные которые уже в hiddenIds
        val visible = all.filter { !(it.done && hiddenIds.contains(it.id)) }

        // Сортировка: сначала с временем (по возрастанию), потом без времени
        plans = visible.sortedWith(compareBy(
            { it.time == null },   // false (есть время) идёт раньше true (нет времени)
            { it.time ?: "" }      // по времени по возрастанию
        ))
    }

    override fun getCount() = plans.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= plans.size) return RemoteViews(context.packageName, R.layout.widget_plan_item)
        val plan = plans[position]
        val views = RemoteViews(context.packageName, R.layout.widget_plan_item)

        if (plan.done) {
            // Выполнен: зачёркнутый текст, серый
            views.setTextViewText(R.id.widget_item_check, "✓")
            views.setTextColor(R.id.widget_item_check, 0xFF888888.toInt())
            views.setInt(R.id.widget_item_text, "setPaintFlags",
                Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG)
            views.setTextColor(R.id.widget_item_text, 0xFF888888.toInt())
            views.setTextViewText(R.id.widget_item_text, plan.text)
        } else {
            // Не выполнен
            views.setTextViewText(R.id.widget_item_check, "○")
            views.setTextColor(R.id.widget_item_check, 0xFFAAAAAA.toInt())
            views.setInt(R.id.widget_item_text, "setPaintFlags", Paint.ANTI_ALIAS_FLAG)
            views.setTextColor(R.id.widget_item_text, 0xFFFFFFFF.toInt())
            views.setTextViewText(R.id.widget_item_text, plan.text)
        }

        // Время — только если есть, перед текстом
        if (!plan.time.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_item_time, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_item_time, plan.time)
            views.setTextColor(R.id.widget_item_time, 0xFF888888.toInt())
        } else {
            views.setViewVisibility(R.id.widget_item_time, android.view.View.GONE)
        }

        // fillInIntent для toggle — передаём id
        val fillIntent = Intent().apply {
            putExtra(PlannerWidget.EXTRA_PLAN_ID, plan.id)
        }
        views.setOnClickFillInIntent(R.id.widget_item_root, fillIntent)

        return views
    }

    override fun getLoadingView() = null
    override fun getViewTypeCount() = 1
    override fun getItemId(position: Int) = if (position < plans.size)
        plans[position].id.hashCode().toLong() else position.toLong()
    override fun hasStableIds() = true
}
