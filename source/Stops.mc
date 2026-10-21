import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Shared description of the city slots (Origin > Change 1 > Change 2 > Destination) and the property keys behind
// them. Change 2 is only part of the journey when the user has chosen two plane changes (see activeSlots()).
(:background)
module Stops {

    const COUNT = 4;   // number of slots

    // Index = slot. null = not applicable for that slot.
    const LABEL_KEYS = ["StartLabel", "Change1Label", "Change2Label", "DestLabel"];
    const OFFSET_KEYS = [null, "Change1Offset", "Change2Offset", "DestOffset"];   // Origin follows the watch's time zone
    const BOARDING_KEYS = ["StartBoarding", "Change1Boarding", "Change2Boarding", null];
    const FLIGHT_KEYS = ["StartFlightMin", "Change1FlightMin", "Change2FlightMin", null];  // flight leaving this slot, minutes

    // Minutes before boarding at which the alarm rings (0 = off). Only cities with a boarding time have one.
    const ALARM_KEYS = ["StartAlarmMin", "Change1AlarmMin", "Change2AlarmMin", null];

    const TAGS = ["START", "CH1", "CH2", "DEST"];

    // UTC offsets (minutes) offered when choosing a time zone; order matches tzLabelIds().
    const TZ_OFFSETS = [-720, -660, -600, -540, -480, -420, -360, -300, -240, -210, -180, -120, -60,
        0, 60, 120, 180, 210, 240, 270, 300, 330, 345, 360, 390, 420, 480, 540, 570, 600, 660, 720, 780];

    function getString(key as String, fallback as String) as String {
        var v = Application.Properties.getValue(key);
        return (v instanceof String) ? v : fallback;
    }

    function getNumber(key as String, fallback as Number) as Number {
        var v = Application.Properties.getValue(key);
        return (v instanceof Number) ? v : fallback;
    }

    // 1 or 2 plane changes (Settings: PlaneChanges)
    function planeChanges() as Number {
        return getNumber("PlaneChanges", 1) == 2 ? 2 : 1;
    }

    // Slots that are part of the journey, in travel order: [0,1,3] with one change, [0,1,2,3] with two
    function activeSlots() as Array<Number> {
        return planeChanges() == 2 ? [0, 1, 2, 3] : [0, 1, 3];
    }

    // Tag shown above a city: START, CH1, CH2 (only with two changes) or DEST, from its position in the journey
    function tagFor(position as Number, activeCount as Number) as String {
        if (position == 0) {
            return TAGS[0];
        }
        return position == activeCount - 1 ? TAGS[3] : TAGS[position];
    }

    // The slot in focus (shown in the middle). Falls back to Change 1 if it is not part of the journey.
    function focusIndex() as Number {
        var f = getNumber("FocusIndex", 0);
        return activeSlots().indexOf(f) >= 0 ? f : 1;
    }

    // UP / DOWN: move the focus to the previous / next city of the journey, wrapping round
    function moveFocus(step as Number) as Void {
        var slots = activeSlots();
        var pos = slots.indexOf(focusIndex());
        Application.Properties.setValue("FocusIndex", slots[(pos + step + slots.size()) % slots.size()]);
    }

    function label(stop as Number) as String {
        return getString(LABEL_KEYS[stop] as String, "");
    }

    // Offset of the stop's local time from UTC in minutes. Origin uses the watch's own zone (DST included).
    function offsetMin(stop as Number) as Number {
        var key = OFFSET_KEYS[stop];
        return key == null ? System.getClockTime().timeZoneOffset / 60 : getNumber(key as String, 0);
    }

    function flightMinutes(stop as Number) as Number {
        var key = FLIGHT_KEYS[stop];
        return key == null ? 0 : getNumber(key as String, 0);
    }

    // UTC seconds at which the flight leaving `stop` was started with the START button, or null.
    function flightStart(stop as Number) as Number? {
        var v = Application.Storage.getValue("FlightStart" + stop);
        return (v instanceof Number) ? v : null;
    }

    function setFlightStart(stop as Number, utcSecs as Number?) as Void {
        if (utcSecs == null) {
            Application.Storage.deleteValue("FlightStart" + stop);
        } else {
            Application.Storage.setValue("FlightStart" + stop, utcSecs);
        }
    }

    // Parses "YYYY-MM-DD HH:MM" into seconds on the "local wall clock as UTC" scale, or null if it is not set
    function parseBoarding(s as String) as Number? {
        if (s.length() < 16) {
            return null;
        }
        var year = s.substring(0, 4).toNumber();
        var month = s.substring(5, 7).toNumber();
        var day = s.substring(8, 10).toNumber();
        var hour = s.substring(11, 13).toNumber();
        var minute = s.substring(14, 16).toNumber();
        if (year == null || month == null || day == null || hour == null || minute == null) {
            return null;
        }
        return Gregorian.moment({
            :year => year, :month => month, :day => day, :hour => hour, :minute => minute
        }).value();
    }

    // "YYYY-MM-DD HH:MM" from seconds on the "local wall clock as UTC" scale
    function stringFromLocal(localSecs as Number) as String {
        var b = Gregorian.utcInfo(new Time.Moment(localSecs), Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$ $4$:$5$", [b.year, b.month.format("%02d"), b.day.format("%02d"),
            b.hour.format("%02d"), b.min.format("%02d")]);
    }

    function hour12(hour as Number) as Number {
        var h = hour % 12;
        return h == 0 ? 12 : h;
    }

    // 24h hour/minute -> "h:mma" / "h:mmp"
    function clock12(hour as Number, min as Number) as String {
        return hour12(hour) + ":" + min.format("%02d") + (hour < 12 ? "a" : "p");
    }
}
