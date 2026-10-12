package com.kiyidanav.kiyidanav

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Ana ekran kartı: seçili meranın günlük av verimliliği (veriyi uygulama yazar: lib/mera_widget.dart) */
class MeraWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        widgetData.edit().putBoolean("widget_var", true).apply()
        val puan = widgetData.getString("mera_puan", "-1")?.toIntOrNull() ?: -1
        val renk = when {
            puan < 0 -> Color.WHITE
            puan >= 80 -> Color.parseColor("#7CD992")
            puan >= 60 -> Color.parseColor("#FFC857")
            else -> Color.parseColor("#FF8A80")
        }
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.mera_widget).apply {
                setTextViewText(R.id.mera_ad, widgetData.getString("mera_ad", null) ?: "Mera Bilgisi")
                setTextViewText(R.id.mera_skor, widgetData.getString("mera_skor", null) ?: "%–")
                setTextColor(R.id.mera_skor, renk)
                setTextViewText(R.id.mera_etiket, widgetData.getString("mera_etiket", null) ?: "")
                setTextViewText(
                    R.id.mera_ozet,
                    widgetData.getString("mera_ozet", null) ?: "Uygulamayı açınca seçtiğin meranın av verimliliği burada görünür."
                )
                setTextViewText(R.id.mera_balik, widgetData.getString("mera_balik", null) ?: "")
                setTextViewText(R.id.mera_saat, widgetData.getString("mera_saat", null) ?: "Dokun ve aç")
                setOnClickPendingIntent(
                    R.id.mera_kok,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("kiyidanav://mera"))
                )
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // Son kart da kaldırıldı: arka planda boşuna veri çekilmesin
        context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            .edit().putBoolean("widget_var", false).apply()
    }
}
