package com.mytrack.mytrack

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

/** Launchers refuse a widget ("Couldn't add widget") whose layout uses a view RemoteViews doesn't allow. */
class WidgetResourcesTest {
    private val res = File("src/main/res")

    // android.widget classes marked @RemoteView, plus <include>/<merge> which are resolved at inflation.
    private val allowed = setOf(
        "FrameLayout", "LinearLayout", "RelativeLayout", "GridLayout", "AdapterViewFlipper", "ViewFlipper",
        "ListView", "GridView", "StackView", "AnalogClock", "Button", "Chronometer", "ImageButton", "ImageView",
        "ProgressBar", "TextClock", "TextView", "CheckBox", "RadioButton", "RadioGroup", "Switch", "include", "merge",
    )

    private fun xml(f: File): Element =
        DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }.newDocumentBuilder().parse(f).documentElement

    private fun tags(e: Element): List<String> {
        val kids = e.childNodes
        return listOf(e.tagName) + (0 until kids.length).mapNotNull { kids.item(it) as? Element }.flatMap(::tags)
    }

    @Test fun everyWidgetLayoutUsesOnlyRemoteViewsSafeViews() {
        val layouts = res.resolve("layout").listFiles { f -> f.name.startsWith("widget_") }!!
        assertTrue("no widget layouts found", layouts.isNotEmpty())
        for (f in layouts) {
            val bad = tags(xml(f)).filterNot { it in allowed }
            assertEquals("${f.name} uses views widgets can't show", emptyList<String>(), bad)
        }
    }

    @Test fun singleHabitWidgetsAlwaysAskWhichHabit() {
        for (name in listOf("ring", "streak", "quick")) {
            val info = xml(res.resolve("xml/widget_${name}_info.xml"))
            val ns = "http://schemas.android.com/apk/res/android"
            assertEquals(name, "com.mytrack.mytrack.WidgetConfig", info.getAttributeNS(ns, "configure"))
            // configuration_optional lets launchers skip the picker entirely, leaving no way to choose the habit.
            assertTrue(name, "configuration_optional" !in info.getAttributeNS(ns, "widgetFeatures"))
        }
    }
}
