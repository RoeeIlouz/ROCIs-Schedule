package com.rocisapps.schedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ScheduleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_schedule_up_next)

                val hasUpcoming = widgetData.getBoolean("schedule_has_upcoming", false)
                val header = widgetData.getString("schedule_up_next_header", "NEXT CLASS") ?: "NEXT CLASS"
                val title = widgetData.getString("schedule_up_next_title", "No more classes today") ?: "No more classes today"
                val subtitle = widgetData.getString("schedule_up_next_subtitle", "You're all caught up!") ?: ""
                val time = widgetData.getString("schedule_up_next_time", "--") ?: "--"
                val colorHex = widgetData.getString("schedule_up_next_color", "#4F46E5") ?: "#4F46E5"

                views.setTextViewText(R.id.widget_schedule_header, header.uppercase())
                views.setTextViewText(R.id.widget_schedule_title, title)
                views.setTextViewText(R.id.widget_schedule_subtitle, subtitle)
                views.setTextViewText(R.id.widget_schedule_time_badge, time)

                try {
                    val parsedColor = Color.parseColor(colorHex)
                    views.setInt(R.id.widget_schedule_bar, "setColorFilter", parsedColor)
                    views.setTextColor(R.id.widget_schedule_header, parsedColor)
                } catch (_: Exception) {}

                views.setViewVisibility(
                    R.id.widget_schedule_subtitle,
                    if (subtitle.isEmpty()) View.GONE else View.VISIBLE
                )

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocisschedule://schedule")
                )
                views.setOnClickPendingIntent(R.id.widget_schedule_root, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (_: Exception) {}
        }
    }
}
