package com.mytrack.mytrack

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WidgetsTest {
    // What lib/system.dart's widgetState() sends after "Smoking" (id 1) was deleted.
    private val afterDelete = """{"seconds":true,"habits":[
        {"id":2,"name":"Sugar","icon":59082,"last":0,"target":null,"base":0,"label":"Best"}]}"""

    @Test fun widgetPickedForADeletedHabitShowsAnotherHabitNotTheDeletedOne() {
        val h = pick(parseState(afterDelete).habits, chosen = 1)
        assertEquals("Sugar", h?.name)
    }

    @Test fun widgetShowsTheEmptyStateWhenTheLastHabitIsDeleted() {
        assertNull(pick(parseState("""{"seconds":true,"habits":[]}""").habits, chosen = 1))
    }

    @Test fun widgetKeepsItsPickedHabitWhenAnotherIsDeleted() {
        assertEquals(2, pick(parseState(afterDelete).habits, chosen = 2)?.id)
    }
}
