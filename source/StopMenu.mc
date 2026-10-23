import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

// START-button menu for one stop: time zone, airport name, boarding time, flight time, start/stop flight.
module StopMenu {


    const MONTHS =["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    function tzLabelIds() as Array<ResourceId> {
        return [Rez.Strings.TzM720, Rez.Strings.TzM660, Rez.Strings.TzM600, Rez.Strings.TzM540, Rez.Strings.TzM480,
            Rez.Strings.TzM420, Rez.Strings.TzM360, Rez.Strings.TzM300, Rez.Strings.TzM240, Rez.Strings.TzM210,
            Rez.Strings.TzM180, Rez.Strings.TzM120, Rez.Strings.TzM60, Rez.Strings.TzP0, Rez.Strings.TzP60,
            Rez.Strings.TzP120, Rez.Strings.TzP180, Rez.Strings.TzP210, Rez.Strings.TzP240, Rez.Strings.TzP270,
            Rez.Strings.TzP300, Rez.Strings.TzP330, Rez.Strings.TzP345, Rez.Strings.TzP360, Rez.Strings.TzP390,
            Rez.Strings.TzP420, Rez.Strings.TzP480, Rez.Strings.TzP540, Rez.Strings.TzP570, Rez.Strings.TzP600,
            Rez.Strings.TzP660, Rez.Strings.TzP720, Rez.Strings.TzP780];
    }

    function open(stop as Number) as Void {
        var menu = new WatchUi.Menu2({ :title => Stops.label(stop) });

        // First item: one or two plane changes (3 or 4 cities in the journey)
        menu.addItem(new WatchUi.MenuItem("Journey", Stops.planeChanges() == 2 ? "2 plane changes" : "1 plane change",
            :journey, {}));

        if (Stops.OFFSET_KEYS[stop] != null) {
            menu.addItem(new WatchUi.MenuItem("Time zone", offsetText(Stops.offsetMin(stop)), :zone, {}));
        }
        menu.addItem(new WatchUi.MenuItem("Airport ID", Stops.code(stop).length() > 0 ? Stops.code(stop) : "not set", :code, {}));
        if (Stops.BOARDING_KEYS[stop] != null) {
            var boarding = Stops.getString(Stops.BOARDING_KEYS[stop] as String, "");
            menu.addItem(new WatchUi.MenuItem("Boarding time", boarding.length() >= 16 ? boarding : "not set", :boarding, {}));
            var lead = Alarms.leadMinutes(stop);
            menu.addItem(new WatchUi.MenuItem("Alarm", lead > 0 ? lead + " min before boarding" : "Off", :alarm, {}));
        }
        if (Stops.FLIGHT_KEYS[stop] != null) {
            menu.addItem(new WatchUi.MenuItem("Flight time", durationText(Stops.flightMinutes(stop)), :flight, {}));
            menu.addItem(new WatchUi.MenuItem(Stops.flightStart(stop) == null ? "Start flight" : "Stop flight",
                null, :toggle, {}));
        }
        WatchUi.pushView(menu, new StopMenuDelegate(stop), WatchUi.SLIDE_UP);
    }

    function daysInMonth(month as Number, year as Number) as Number {
        if (month == 2) {
            var leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
            return leap ? 29 : 28;
        }
        return (month == 4 || month == 6 || month == 9 || month == 11) ? 30 : 31;
    }

    // The year (previous, current or next) that puts month/day closest to `localNow`, so a Dec 31 flight
    // entered on Jan 2 (or the reverse) lands in the right year.
    function nearestYear(month as Number, day as Number, localNow as Number) as Number {
        var thisYear = Gregorian.utcInfo(new Time.Moment(localNow), Time.FORMAT_SHORT).year;
        var best = thisYear;
        var bestDiff = 0x7FFFFFFF;
        for (var y = thisYear - 1; y <= thisYear + 1; y++) {
            var d = day > daysInMonth(month, y) ? daysInMonth(month, y) : day;
            var secs = Gregorian.moment({ :year => y, :month => month, :day => d }).value();
            var diff = (secs - localNow).abs();
            if (diff < bestDiff) {
                bestDiff = diff;
                best = y;
            }
        }
        return best;
    }

    // Step 2 of boarding entry: replaces the date picker with an hour : minute (+ AM/PM) picker
    function pushBoardingTimePicker(stop as Number, year as Number, month as Number, day as Number) as Void {
        // Follow the watch's own clock setting (System > Time Format): 24-hour or 12-hour with AM/PM
        var is24 = System.getDeviceSettings().is24Hour;
        var hourLabels = [] as Array<String>;
        var hourValues = [] as Array<Number>;
        for (var h = is24 ? 0 : 1; h <= (is24 ? 23 : 12); h++) {
            hourLabels.add(is24 ? h.format("%02d") : h.format("%d"));
            hourValues.add(h);
        }
        var minLabels = [] as Array<String>;
        var minValues = [] as Array<Number>;
        for (var m = 0; m < 60; m += 5) {
            minLabels.add(m.format("%02d"));
            minValues.add(m);
        }

        // Start on the current boarding time if one is set, otherwise on the current local time
        var hour24 = Gregorian.utcInfo(new Time.Moment(Time.now().value() + Stops.offsetMin(stop) * 60),
            Time.FORMAT_SHORT).hour;
        var minute = 0;
        var current = Stops.getString(Stops.BOARDING_KEYS[stop] as String, "");
        if (current.length() >= 16) {
            var ch = current.substring(11, 13).toNumber();
            var cm = current.substring(14, 16).toNumber();
            if (ch != null && cm != null) {
                hour24 = ch;
                minute = cm;
            }
        }

        // Hour : minute [AM/PM] side by side on one screen
        var labels = [hourLabels, minLabels] as Array<Array<String> >;
        var values = [hourValues, minValues] as Array<Array<Number> >;
        var defaults = [is24 ? hour24 : Stops.hour12(hour24) - 1, (minute / 5) % 12] as Array<Number>;
        var separators = [":"];
        if (!is24) {
            labels.add(["AM", "PM"]);
            values.add([0, 1]);
            defaults.add(hour24 >= 12 ? 1 : 0);
            separators.add("");
        }
        showFields("Boarding time", MONTHS[month - 1] + " " + day, labels, values, defaults, separators,
            new BoardingTimeHandler(stop, year, month, day, is24), true);
    }

    // Show a one-screen multi-field picker; `replace` swaps it in for the current view instead of pushing on top
    function showFields(title as String, subtitle as String?, labels as Array<Array<String> >,
            values as Array<Array<Number> >, defaults as Array<Number>, separators as Array<String>,
            handler, replace as Boolean) as Void {
        var view = new FieldPickerView(title, subtitle, labels, values, defaults, separators);
        var delegate = new FieldPickerDelegate(view, handler);
        if (replace) {
            WatchUi.switchToView(view, delegate, WatchUi.SLIDE_LEFT);
        } else {
            WatchUi.pushView(view, delegate, WatchUi.SLIDE_UP);
        }
    }

    function offsetText(minutes as Number) as String {
        var sign = minutes < 0 ? "-" : "+";
        var abs = minutes < 0 ? -minutes : minutes;
        return "UTC" + sign + (abs / 60).format("%02d") + ":" + (abs % 60).format("%02d");
    }

    function durationText(minutes as Number) as String {
        return (minutes / 60) + "h " + (minutes % 60).format("%02d") + "m";
    }

    // Back to the main screen (closes the pushed picker/menu and the stop menu beneath it)
    function closeAll(depth as Number) as Void {
        for (var i = 0; i < depth; i++) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        Alarms.schedule();   // boarding time, time zone, alarm or journey may have changed
        WatchUi.requestUpdate();
    }
}

class StopMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _stop as Number;

    function initialize(stop as Number) {
        Menu2InputDelegate.initialize();
        _stop = stop;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :journey) {
            pushJourneyMenu();
        } else if (id == :zone) {
            pushZoneMenu();
        } else if (id == :code) {
            pushAirportLetterPicker();
        } else if (id == :boarding) {
            pushBoardingPicker();
        } else if (id == :alarm) {
            pushAlarmPicker();
        } else if (id == :flight) {
            pushFlightPicker();
        } else if (id == :toggle) {
            // START begins the flight (flown/remaining start counting); selecting again stops/resets it
            Stops.setFlightStart(_stop, Stops.flightStart(_stop) == null ? Time.now().value() : null);
            StopMenu.closeAll(1);
        }
    }

    // Airport ID: pick the first letter, then the airport from the (short) list of codes starting with it
    private function pushAirportLetterPicker() as Void {
        var letters = [] as Array<String>;
        var values = [] as Array<Number>;
        for (var i = 0; i < 26; i++) {
            letters.add(("ABCDEFGHIJKLMNOPQRSTUVWXYZ").substring(i, i + 1) as String);
            values.add(i);
        }
        var code = Stops.code(_stop);
        var first = code.length() > 0 ? code.toUpper().toCharArray()[0].toNumber() - 65 : 0;
        StopMenu.showFields("Airport ID", "First letter", [letters] as Array<Array<String> >,
            [values] as Array<Array<Number> >, [first >= 0 && first < 26 ? first : 0] as Array<Number>, [],
            new AirportLetterHandler(_stop), false);
    }

    private function pushJourneyMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => "Journey" });
        menu.addItem(new WatchUi.MenuItem("1 plane change", "Origin, Change 1, Destination", 1, {}));
        menu.addItem(new WatchUi.MenuItem("2 plane changes", "Origin, Change 1, Change 2, Destination", 2, {}));
        WatchUi.pushView(menu, new JourneyMenuDelegate(), WatchUi.SLIDE_LEFT);
    }

    private function pushZoneMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => "Time zone" });
        var ids = StopMenu.tzLabelIds();
        for (var i = 0; i < Stops.TZ_OFFSETS.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource(ids[i]) as String, null, Stops.TZ_OFFSETS[i], {}));
        }
        WatchUi.pushView(menu, new ZoneMenuDelegate(_stop), WatchUi.SLIDE_LEFT);
    }

    // Boarding entry runs in two Garmin-style steps: month + day on one screen, then hour : minute.
    private function pushBoardingPicker() as Void {
        var localNow = Time.now().value() + Stops.offsetMin(_stop) * 60;
        var today = Gregorian.utcInfo(new Time.Moment(localNow), Time.FORMAT_SHORT);

        var monthValues = [] as Array<Number>;
        for (var m = 1; m <= 12; m++) {
            monthValues.add(m);
        }
        var dayLabels = [] as Array<String>;
        var dayValues = [] as Array<Number>;
        for (var d = 1; d <= 31; d++) {
            dayLabels.add(d.format("%d"));
            dayValues.add(d);
        }

        // Start on the current boarding date if one is set, otherwise on today
        var month = today.month;
        var day = today.day;
        var current = Stops.getString(Stops.BOARDING_KEYS[_stop] as String, "");
        if (current.length() >= 16) {
            var cm = current.substring(5, 7).toNumber();
            var cd = current.substring(8, 10).toNumber();
            if (cm != null && cd != null && cm >= 1 && cm <= 12 && cd >= 1 && cd <= 31) {
                month = cm;
                day = cd;
            }
        }

        StopMenu.showFields("Boarding Date", null,
            [StopMenu.MONTHS, dayLabels] as Array<Array<String> >, [monthValues, dayValues] as Array<Array<Number> >,
            [month - 1, day - 1] as Array<Number>, [""], new BoardingDateHandler(_stop, localNow), false);
    }

    // Minutes before boarding at which the alarm rings (Off, 5 ... 120)
    private function pushAlarmPicker() as Void {
        var labels = [] as Array<String>;
        var current = Alarms.leadMinutes(_stop);
        var defaultIdx = 0;
        for (var i = 0; i < Alarms.LEAD_CHOICES.size(); i++) {
            var m = Alarms.LEAD_CHOICES[i];
            labels.add(m == 0 ? "Off" : m + " min");
            if (m == current) {
                defaultIdx = i;
            }
        }
        StopMenu.showFields("Alarm before boarding", Stops.label(_stop),
            [labels] as Array<Array<String> >, [Alarms.LEAD_CHOICES] as Array<Array<Number> >,
            [defaultIdx] as Array<Number>, [], new AlarmHandler(_stop), false);
    }

    private function pushFlightPicker() as Void {
        var hourLabels = [] as Array<String>;
        var hourValues = [] as Array<Number>;
        for (var h = 0; h <= 24; h++) {
            hourLabels.add(h + "h");
            hourValues.add(h);
        }
        var minLabels = [] as Array<String>;
        var minValues = [] as Array<Number>;
        for (var m = 0; m < 60; m += 5) {
            minLabels.add(m.format("%02d") + "m");
            minValues.add(m);
        }
        var total = Stops.flightMinutes(_stop);
        StopMenu.showFields("Flight time", null,
            [hourLabels, minLabels] as Array<Array<String> >, [hourValues, minValues] as Array<Array<Number> >,
            [(total / 60) % 25, (total % 60) / 5] as Array<Number>, [""], new FlightHandler(_stop), false);
    }
}

class JourneyMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Application.Properties.setValue("PlaneChanges", item.getId() as Number);
        // If the city in focus is no longer part of the journey (Change 2 after going back to one change),
        // Stops.focusIndex() falls back to Change 1 on its own
        StopMenu.closeAll(2);
    }
}

class ZoneMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _stop as Number;

    function initialize(stop as Number) {
        Menu2InputDelegate.initialize();
        _stop = stop;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        Application.Properties.setValue(Stops.OFFSET_KEYS[_stop] as String, item.getId() as Number);
        StopMenu.closeAll(2);
    }
}

// Airport ID entry, step 1: first letter of the IATA code. Replaces the picker with the list for that letter.
class AirportLetterHandler {

    private var _stop as Number;

    function initialize(stop as Number) {
        _stop = stop;
    }

    function onAccept(values as Array<Number>) as Void {
        var view = new AirportListView(values[0], Stops.code(_stop));
        WatchUi.switchToView(view, new AirportListInputDelegate(view, _stop), WatchUi.SLIDE_LEFT);
    }

    function onCancel() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// Handlers for FieldPickerDelegate: onAccept(values) receives the selected value of each field, in order.

// Step 1 of boarding entry: month + day. Accepting moves on to the time screen.
class BoardingDateHandler {

    private var _stop as Number;
    private var _localNow as Number;

    function initialize(stop as Number, localNow as Number) {
        _stop = stop;
        _localNow = localNow;
    }

    function onAccept(values as Array<Number>) as Void {
        var month = values[0];
        var day = values[1];
        var year = StopMenu.nearestYear(month, day, _localNow);
        var maxDay = StopMenu.daysInMonth(month, year);
        day = day > maxDay ? maxDay : day;   // e.g. Feb 31 becomes the last day of February
        StopMenu.pushBoardingTimePicker(_stop, year, month, day);
    }

    function onCancel() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// Step 2 of boarding entry: hour : minute (+ AM/PM). Saves "YYYY-MM-DD HH:MM" in the airport's local time.
class BoardingTimeHandler {

    private var _stop as Number;
    private var _year as Number;
    private var _month as Number;
    private var _day as Number;
    private var _is24 as Boolean;

    function initialize(stop as Number, year as Number, month as Number, day as Number, is24 as Boolean) {
        _stop = stop;
        _year = year;
        _month = month;
        _day = day;
        _is24 = is24;
    }

    function onAccept(values as Array<Number>) as Void {
        // values = [hour, minute] plus an AM/PM flag (0/1) on a 12-hour watch
        var hour24 = _is24 ? values[0] : (values[0] % 12) + (values[2] == 1 ? 12 : 0);
        var text = Lang.format("$1$-$2$-$3$ $4$:$5$", [_year, _month.format("%02d"), _day.format("%02d"),
            hour24.format("%02d"), values[1].format("%02d")]);
        Application.Properties.setValue(Stops.BOARDING_KEYS[_stop] as String, text);
        StopMenu.closeAll(2);   // the time screen + the stop menu beneath it
    }

    function onCancel() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class FlightHandler {

    private var _stop as Number;

    function initialize(stop as Number) {
        _stop = stop;
    }

    function onAccept(values as Array<Number>) as Void {
        Application.Properties.setValue(Stops.FLIGHT_KEYS[_stop] as String, values[0] * 60 + values[1]);
        StopMenu.closeAll(2);
    }

    function onCancel() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class AlarmHandler {

    private var _stop as Number;

    function initialize(stop as Number) {
        _stop = stop;
    }

    function onAccept(values as Array<Number>) as Void {
        Application.Properties.setValue(Stops.ALARM_KEYS[_stop] as String, values[0]);
        StopMenu.closeAll(2);
    }

    function onCancel() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
