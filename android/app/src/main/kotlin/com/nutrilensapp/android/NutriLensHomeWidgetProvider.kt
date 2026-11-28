package com.nutrilensapp.android

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home-screen widget that mirrors today's meal & water summary.
 *
 * Tap behavior:
 * - Tapping the widget body or "Tara" opens the app (`nutrilens://widget/scan`).
 * - Tapping "+1 Su" fires an explicit broadcast (`ACTION_ADD_WATER`) handled
 *   directly in [onReceive] — incrementing today's water count and queueing the
 *   delta for Flutter to flush into Drift on next app launch/resume, WITHOUT
 *   opening the app.
 *
 * Every exception is swallowed and logged — a single crash here makes Android
 * show "Can't load widget" on the home screen until the user removes and
 * re-adds the widget.
 */
class NutriLensHomeWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "NutriLensWidget"
        private const val ACTION_ADD_WATER = "com.nutrilensapp.android.ACTION_ADD_WATER"
        private const val REQUEST_CODE_ADD_WATER = 4102

        private const val KEY_WATER_GLASSES = "today_water_glasses"
        private const val KEY_WATER_GOAL = "today_water_goal"
        private const val KEY_WATER_DAY = "today_water_day"
        private const val KEY_PENDING_WATER_QUEUE = "pending_water_queue"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_ADD_WATER) {
            handleAddWater(context)
        }
    }

    private fun handleAddWater(context: Context) {
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            val todayKey = todayDayKey()
            val storedDay = prefs.getString(KEY_WATER_DAY, null)
            val currentGlasses = if (storedDay == null || storedDay == todayKey) {
                prefs.getInt(KEY_WATER_GLASSES, 0)
            } else {
                0
            }
            val nextGlasses = currentGlasses + 1

            val pendingRaw = prefs.getString(KEY_PENDING_WATER_QUEUE, "") ?: ""
            val nextPending = incrementPendingQueue(pendingRaw, todayKey)

            prefs.edit()
                .putInt(KEY_WATER_GLASSES, nextGlasses)
                .putString(KEY_WATER_DAY, todayKey)
                .putString(KEY_PENDING_WATER_QUEUE, nextPending)
                .commit()

            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, NutriLensHomeWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                onUpdate(context, manager, ids)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Failed handling background +1 water tap", t)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        var kcal = 0
        var mealCount = 0
        var proteinPct = 0
        var carbPct = 0
        var fatPct = 0
        var waterGlasses = 0
        var waterGoal = 10
        val todayKey = todayDayKey()
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            kcal = prefs.getInt("today_kcal", 0)
            mealCount = prefs.getInt("today_meal_count", 0)
            proteinPct = prefs.getInt("today_protein_pct", 0)
            carbPct = prefs.getInt("today_carb_pct", 0)
            fatPct = prefs.getInt("today_fat_pct", 0)
            val storedDay = prefs.getString(KEY_WATER_DAY, null)
            waterGlasses = if (storedDay == null || storedDay == todayKey) {
                prefs.getInt(KEY_WATER_GLASSES, 0)
            } else {
                0
            }
            val savedGoal = prefs.getInt(KEY_WATER_GOAL, 10)
            if (savedGoal > 0) waterGoal = savedGoal
        } catch (t: Throwable) {
            Log.e(TAG, "Failed reading widget data, falling back to zeros", t)
        }

        val waterPct = ((waterGlasses * 100) / waterGoal).coerceIn(0, 100)

        for (widgetId in appWidgetIds) {
            try {
                val views = RemoteViews(
                    context.packageName,
                    R.layout.nutrilens_home_widget
                )
                views.setTextViewText(R.id.widget_kcal, formatKcal(kcal))
                views.setTextViewText(R.id.widget_meal_count, "$mealCount öğün")
                views.setTextViewText(
                    R.id.widget_water_status,
                    "💧 $waterGlasses/$waterGoal"
                )
                views.setProgressBar(R.id.widget_water_bar, 100, waterPct, false)
                views.setTextViewText(R.id.widget_protein_label, "P %$proteinPct")
                views.setProgressBar(R.id.widget_protein_bar, 100, proteinPct, false)
                views.setTextViewText(R.id.widget_carb_label, "K %$carbPct")
                views.setProgressBar(R.id.widget_carb_bar, 100, carbPct, false)
                views.setTextViewText(R.id.widget_fat_label, "Y %$fatPct")
                views.setProgressBar(R.id.widget_fat_bar, 100, fatPct, false)

                val scanIntent: PendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("nutrilens://widget/scan")
                )
                val waterBroadcast = Intent(
                    context,
                    NutriLensHomeWidgetProvider::class.java
                ).apply {
                    action = ACTION_ADD_WATER
                }
                val waterIntent: PendingIntent = PendingIntent.getBroadcast(
                    context,
                    REQUEST_CODE_ADD_WATER,
                    waterBroadcast,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                views.setOnClickPendingIntent(R.id.widget_root, scanIntent)
                views.setOnClickPendingIntent(R.id.widget_scan_button, scanIntent)
                views.setOnClickPendingIntent(R.id.widget_water_button, waterIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to bind widget id=$widgetId", t)
            }
        }
    }

    private fun todayDayKey(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    private fun incrementPendingQueue(raw: String, dayKey: String): String {
        val map = linkedMapOf<String, Int>()
        if (raw.isNotBlank()) {
            for (entry in raw.split(",")) {
                val parts = entry.trim().split(":")
                if (parts.size != 2) continue
                val d = parts[0].trim()
                val c = parts[1].trim().toIntOrNull() ?: continue
                if (d.isNotEmpty() && c > 0) {
                    map[d] = (map[d] ?: 0) + c
                }
            }
        }
        map[dayKey] = (map[dayKey] ?: 0) + 1
        return map.entries
            .sortedBy { it.key }
            .joinToString(",") { "${it.key}:${it.value}" }
    }

    private fun formatKcal(kcal: Int): String {
        if (kcal < 1000) return kcal.toString()
        val thousand = kcal / 1000
        val rest = kcal % 1000
        return "$thousand.${rest.toString().padStart(3, '0')}"
    }
}
