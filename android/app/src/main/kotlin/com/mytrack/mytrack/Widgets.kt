package com.mytrack.mytrack

import android.app.Activity
import android.app.AlarmManager
import android.app.AlertDialog
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.min

// Home-screen widgets (design 1b, 1c). The app writes a JSON snapshot via home_widget (lib/system.dart);
// these providers render it and refresh themselves once a minute while any widget exists.
// The interval rule and formatting mirror lib/logic.dart.

private const val HOUR = 3_600_000L
private const val MINUTE = 60_000L
private const val ACCENT = 0xFF9184D9.toInt()
private const val A300 = 0xFFD2CEFD.toInt()
private const val N400 = 0xFFB2B6CA.toInt()
private const val N800 = 0xFF3F424D.toInt()
private const val FAIL = 0xFFEF9497.toInt()
private const val HAND_PALM = 0xe57e
private const val FLAME = 0xe624

class Habit(val id: Int, val name: String, val icon: Int, val last: Long, val target: Long?, val base: Int, val label: String) {
    fun el(now: Long) = now - last
    fun beat(now: Long) = target != null && el(now) > target
    fun streak(now: Long) = base + if (beat(now)) 1 else 0
    fun progress(now: Long) = if (target == null || target == 0L) 1000 else min(1000L, el(now) * 1000 / target).toInt()
    fun color(now: Long) = when { target == null -> N400; beat(now) -> A300; else -> FAIL }
    fun shortStatus(now: Long) = when {
        target == null -> "Setting the bar"
        beat(now) -> "Beaten ✓"
        else -> "${fmt(target - el(now))} to go"
    }
    fun statusText(now: Long) = when {
        target == null -> "First interval — this sets the bar"
        beat(now) -> "Beaten by ${fmt(el(now) - target)} — keep going"
        else -> "${fmt(target - el(now))} left or it's a fail"
    }
    fun targetText() = if (target == null) "—" else "$label ${fmt(target)}"
}

fun fmt(ms0: Long): String {
    val ms = max(0L, ms0)
    val m = ms / MINUTE; val h = m / 60; val d = h / 24
    return when {
        d > 0 -> "${d}d ${h % 24}h"
        h > 0 -> "${h}h ${"%02d".format(m % 60)}m"
        else -> "${m}m ${"%02d".format(ms / 1000 % 60)}s"
    }
}

class WidgetState(val seconds: Boolean, val habits: List<Habit>)

private fun state(data: SharedPreferences): WidgetState {
    val o = JSONObject(data.getString("state", null) ?: "{}")
    val a = o.optJSONArray("habits")
    val habits = (0 until (a?.length() ?: 0)).map {
        val h = a!!.getJSONObject(it)
        Habit(h.getInt("id"), h.getString("name"), h.getInt("icon"), h.getLong("last"),
            if (h.isNull("target")) null else h.getLong("target"), h.getInt("base"), h.optString("label", "Best"))
    }
    return WidgetState(o.optBoolean("seconds", true), habits)
}

private fun choices(ctx: Context) = ctx.getSharedPreferences("mytrack_widgets", Context.MODE_PRIVATE)

private fun dp(ctx: Context, v: Float) = (v * ctx.resources.displayMetrics.density).toInt()

private var phosphor: Typeface? = null
private var phosphorFill: Typeface? = null

/** Draws a Phosphor glyph (the app's bundled icon font) to a bitmap; RemoteViews can't use custom fonts. */
private fun glyph(ctx: Context, code: Int, sizeDp: Float, color: Int, fill: Boolean = false): Bitmap {
    val tf = if (fill) {
        phosphorFill ?: Typeface.createFromAsset(ctx.assets, "flutter_assets/assets/fonts/Phosphor-Fill.ttf").also { phosphorFill = it }
    } else {
        phosphor ?: Typeface.createFromAsset(ctx.assets, "flutter_assets/assets/fonts/Phosphor.ttf").also { phosphor = it }
    }
    val px = dp(ctx, sizeDp)
    val b = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = tf; textSize = px.toFloat(); this.color = color; textAlign = Paint.Align.CENTER }
    Canvas(b).drawText(String(Character.toChars(code)), px / 2f, px / 2f - (p.descent() + p.ascent()) / 2, p)
    return b
}

private fun ring(ctx: Context, progress: Int): Bitmap {
    val px = dp(ctx, 92f); val stroke = dp(ctx, 6f).toFloat()
    val b = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val c = Canvas(b)
    val r = RectF(stroke / 2, stroke / 2, px - stroke / 2, px - stroke / 2)
    val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = stroke }
    c.drawArc(r, 0f, 360f, false, p.apply { color = N800 })
    c.drawArc(r, -90f, 360f * progress / 1000, false, p.apply { color = ACCENT })
    return b
}

private fun link(ctx: Context, action: String, id: Int): PendingIntent =
    HomeWidgetLaunchIntent.getActivity(ctx, MainActivity::class.java, Uri.parse("mytrack://$action?id=$id"))

/** Elapsed time: live seconds (Chronometer) under an hour when enabled, minute-refreshed text otherwise. */
private fun elapsed(v: RemoteViews, textId: Int, chronoId: Int, h: Habit, now: Long, seconds: Boolean, short: Boolean) {
    val el = h.el(now)
    val live = seconds && el < HOUR
    v.setViewVisibility(textId, if (live) View.GONE else View.VISIBLE)
    v.setViewVisibility(chronoId, if (live) View.VISIBLE else View.GONE)
    if (live) v.setChronometer(chronoId, SystemClock.elapsedRealtime() - el, null, true)
    else v.setTextViewText(textId, if (short && el < HOUR) "${el / MINUTE}m" else fmt(el))
}

abstract class MyTrackWidget : HomeWidgetProvider() {
    abstract val layout: Int
    open val single = true
    abstract fun fill(ctx: Context, v: RemoteViews, s: WidgetState, h: Habit?, now: Long)

    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val s = state(data); val now = System.currentTimeMillis()
        for (id in ids) {
            val chosen = choices(ctx).getInt("w$id", -1)
            val h = s.habits.firstOrNull { it.id == chosen } ?: s.habits.firstOrNull()
            val v = RemoteViews(ctx.packageName, layout)
            val empty = if (single) h == null else s.habits.isEmpty()
            v.setViewVisibility(R.id.empty, if (empty) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.body, if (empty) View.GONE else View.VISIBLE)
            v.setOnClickPendingIntent(R.id.empty, HomeWidgetLaunchIntent.getActivity(ctx, MainActivity::class.java))
            if (!empty) fill(ctx, v, s, h, now)
            mgr.updateAppWidget(id, v)
        }
        if (ids.isNotEmpty()) tick(ctx, ids)
    }

    /** Re-run onUpdate at the next minute. RTC (not _WAKEUP): a sleeping phone isn't woken just for this. */
    private fun tick(ctx: Context, ids: IntArray) {
        val i = Intent(ctx, javaClass).setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        val pi = PendingIntent.getBroadcast(ctx, 0, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val next = (System.currentTimeMillis() / MINUTE + 1) * MINUTE
        ctx.getSystemService(AlarmManager::class.java).set(AlarmManager.RTC, next, pi)
    }
}

/** 2×2: progress ring around the icon and elapsed time. */
class RingWidget : MyTrackWidget() {
    override val layout = R.layout.widget_ring
    override fun fill(ctx: Context, v: RemoteViews, s: WidgetState, h: Habit?, now: Long) {
        h!!
        v.setImageViewBitmap(R.id.ring, ring(ctx, h.progress(now)))
        v.setImageViewBitmap(R.id.icon, glyph(ctx, h.icon, 16f, A300))
        elapsed(v, R.id.time, R.id.chrono, h, now, s.seconds, short = true)
        v.setTextViewText(R.id.status, h.shortStatus(now))
        v.setTextColor(R.id.status, h.color(now))
        v.setOnClickPendingIntent(R.id.body, link(ctx, "open", h.id))
    }
}

/** 2×2: streak on the indigo section ground. */
class StreakWidget : MyTrackWidget() {
    override val layout = R.layout.widget_streak
    override fun fill(ctx: Context, v: RemoteViews, s: WidgetState, h: Habit?, now: Long) {
        h!!
        v.setImageViewBitmap(R.id.flame, glyph(ctx, FLAME, 30f, 0xFFE7E5FE.toInt(), fill = true))
        v.setTextViewText(R.id.streak, "${h.streak(now)}")
        elapsed(v, R.id.time, R.id.chrono, h, now, s.seconds, short = true)
        v.setTextViewText(R.id.name, h.name)
        v.setOnClickPendingIntent(R.id.body, link(ctx, "open", h.id))
    }
}

/** 4×2: one habit with a quick-log button. */
class QuickWidget : MyTrackWidget() {
    override val layout = R.layout.widget_quick
    override fun fill(ctx: Context, v: RemoteViews, s: WidgetState, h: Habit?, now: Long) {
        h!!
        v.setImageViewBitmap(R.id.icon, glyph(ctx, h.icon, 14f, A300))
        v.setTextViewText(R.id.name, "${h.name} · since last slip")
        elapsed(v, R.id.time, R.id.chrono, h, now, s.seconds, short = true)
        v.setImageViewBitmap(R.id.log, glyph(ctx, HAND_PALM, 20f, A300))
        v.setProgressBar(R.id.bar, 1000, h.progress(now), false)
        v.setTextViewText(R.id.status, h.statusText(now))
        v.setTextColor(R.id.status, h.color(now))
        v.setTextViewText(R.id.target, h.targetText())
        v.setOnClickPendingIntent(R.id.main, link(ctx, "open", h.id))
        v.setOnClickPendingIntent(R.id.log, link(ctx, "log", h.id))
    }
}

/** 4×4: every habit, tap ✋ to log. */
class ListWidget : MyTrackWidget() {
    override val layout = R.layout.widget_list
    override val single = false
    override fun fill(ctx: Context, v: RemoteViews, s: WidgetState, h: Habit?, now: Long) {
        v.setTextViewText(R.id.beaten, "${s.habits.count { it.beat(now) }}/${s.habits.size} beaten")
        v.removeAllViews(R.id.rows)
        for (x in s.habits.take(5)) { // ponytail: 5 rows fill a 4×4; a scrolling list needs a RemoteViewsService
            val r = RemoteViews(ctx.packageName, R.layout.widget_row)
            r.setImageViewBitmap(R.id.icon, glyph(ctx, x.icon, 13f, A300))
            r.setTextViewText(R.id.name, x.name)
            elapsed(r, R.id.time, R.id.chrono, x, now, s.seconds, short = true)
            r.setProgressBar(R.id.bar, 1000, x.progress(now), false)
            r.setTextViewText(R.id.status, x.shortStatus(now))
            r.setTextColor(R.id.status, x.color(now))
            r.setImageViewBitmap(R.id.log, glyph(ctx, HAND_PALM, 15f, 0xFFCFD3E5.toInt()))
            r.setOnClickPendingIntent(R.id.main, link(ctx, "open", x.id))
            r.setOnClickPendingIntent(R.id.log, link(ctx, "log", x.id))
            v.addView(R.id.rows, r)
        }
    }
}

/** Picks which habit a single-habit widget shows. Optional on Android 12+ (defaults to the first habit). */
class WidgetConfig : Activity() {
    override fun onCreate(saved: Bundle?) {
        super.onCreate(saved)
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val done = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
        setResult(RESULT_CANCELED, done)
        val habits = state(es.antonborri.home_widget.HomeWidgetPlugin.getData(this)).habits
        if (habits.isEmpty()) {
            setResult(RESULT_OK, done) // widget shows "add a habit" until there is one
            finish()
            return
        }
        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle("Show which habit?")
            .setItems(habits.map { it.name }.toTypedArray()) { _, i ->
                choices(this).edit().putInt("w$id", habits[i].id).apply()
                val provider: ComponentName? = AppWidgetManager.getInstance(this).getAppWidgetInfo(id)?.provider
                if (provider != null) sendBroadcast(Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).setComponent(provider)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(id)))
                setResult(RESULT_OK, done)
                finish()
            }
            .setOnCancelListener { finish() }
            .show()
    }
}
