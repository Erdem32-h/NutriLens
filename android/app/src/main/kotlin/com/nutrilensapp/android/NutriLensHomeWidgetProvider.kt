package com.nutrilensapp.android

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Home-screen widget that mirrors today's meal summary.
 *
 * The provider is intentionally minimal: read two ints from the
 * `home_widget` SharedPreferences bridge, bind them into the
 * RemoteViews, and wire a click PendingIntent that opens the app via
 * `nutrilens://widget/scan`.
 *
 * Every exception is swallowed and logged — a single crash here makes
 * Android show "Can't load widget" on the home screen until the user
 * removes and re-adds the widget. Better to render zeros than crash.
 */
class NutriLensHomeWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "NutriLensWidget"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        var kcal = 0
        var mealCount = 0
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            kcal = prefs.getInt("today_kcal", 0)
            mealCount = prefs.getInt("today_meal_count", 0)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed reading widget data, falling back to zeros", t)
        }

        for (widgetId in appWidgetIds) {
            try {
                val views = RemoteViews(
                    context.packageName,
                    R.layout.nutrilens_home_widget
                )
                views.setTextViewText(R.id.widget_kcal, formatKcal(kcal))
                views.setTextViewText(
                    R.id.widget_meal_count,
                    "$mealCount öğün · bugün"
                )

                val scanIntent: PendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("nutrilens://widget/scan")
                )
                views.setOnClickPendingIntent(R.id.widget_root, scanIntent)
                views.setOnClickPendingIntent(R.id.widget_scan_button, scanIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to bind widget id=$widgetId", t)
            }
        }
    }

    private fun formatKcal(kcal: Int): String {
        if (kcal < 1000) return kcal.toString()
        val thousand = kcal / 1000
        val rest = kcal % 1000
        return "$thousand.${rest.toString().padStart(3, '0')}"
    }
}
