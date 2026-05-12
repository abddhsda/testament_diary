package com.example.mindful_diary

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class PlannerWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        PlannerListFactory(applicationContext, intent)
}

class PlannerListFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<PlanItem>()
    data class PlanItem(val id: String, val text: String, val time: String?, val done: Boolean)

    override fun onCreate() { loadPlans() }
    override fun onDataSetChanged() { loadPlans() }
    override fun onDestroy() { items.clear() }

    private fun loadPlans() {
        items.clear()
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val plansJson = prefs.getString("flutter.plans", "{}") ?: "{}"
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        try {
            val allPlans = JSONObject(plansJson)
            val todayPlans: JSONArray = allPlans.optJSONArray(today) ?: return
            for (i in 0 until todayPlans.length()) {
                val p = todayPlans.getJSONObject(i)
                items.add(PlanItem(
                    id   = p.optString("id", i.toString()),
                    text = p.optString("text", ""),
                    time = if (p.isNull("time")) null else p.optString("time"),
                    done = p.optBoolean("done", false)
                ))
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    override fun getCount() = items.size
    override fun getItemId(position: Int) = position.toLong()
    override fun hasStableIds() = true
    override fun getLoadingView() = null
    override fun getViewTypeCount() = 1

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= items.size) return RemoteViews(context.packageName, R.layout.widget_plan_item)
        val item = items[position]
        val rv = RemoteViews(context.packageName, R.layout.widget_plan_item)

        rv.setTextViewText(R.id.widget_item_check, if (item.done) "✓" else "○")
        rv.setTextColor(R.id.widget_item_check,
            if (item.done) android.graphics.Color.parseColor("#4CAF50")
            else android.graphics.Color.parseColor("#AAAAAA"))

        rv.setTextViewText(R.id.widget_item_text, item.text)
        rv.setTextColor(R.id.widget_item_text,
            if (item.done) android.graphics.Color.parseColor("#666666")
            else android.graphics.Color.parseColor("#FFFFFF"))

        if (!item.time.isNullOrEmpty()) {
            rv.setViewVisibility(R.id.widget_item_time, android.view.View.VISIBLE)
            rv.setTextViewText(R.id.widget_item_time, "⏰ ${item.time}")
        } else {
            rv.setViewVisibility(R.id.widget_item_time, android.view.View.GONE)
        }

        val fillIntent = Intent().apply { putExtra(PlannerWidget.EXTRA_PLAN_ID, item.id) }
        rv.setOnClickFillInIntent(R.id.widget_item_root, fillIntent)

        return rv
    }
}
