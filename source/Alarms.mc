import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// Boarding alarms. Each city except the destination can ring N minutes before its boarding time.
//  - While the app is open, JagaGarmin1View checks every second and vibrates / beeps / shows a banner.
//  - When the app is closed, a one-shot background event is registered for the next alarm; when it fires the
//    system shows a prompt (with vibration) asking to open the app, which then shows the banner.
// This module also runs in the background process, so it only uses light, annotated code.
(:background)
module Alarms {

    // Alarm lead times offered in the menu, in minutes (0 = off)
    const LEAD_CHOICES = [0, 5, 10, 15, 20, 30, 45, 60, 90, 120];

    function leadMinutes(slot as Number) as Number {
        var key = Stops.ALARM_KEYS[slot];
        return key == null ? 0 : Stops.getNumber(key as String, 0);
    }

    // The boarding time the user entered for this city, as a real UTC time. Placeholders are not alarmed.
    function boardingUtc(slot as Number) as Number? {
        var key = Stops.BOARDING_KEYS[slot];
        if (key == null) {
            return null;
        }
        var local = Stops.parseBoarding(Stops.getString(key as String, ""));
        return local == null ? null : local - Stops.offsetMin(slot) * 60;
    }

    // UTC time the alarm should ring, or null if there is no alarm / no boarding time for this city
    function alarmUtc(slot as Number) as Number? {
        var lead = leadMinutes(slot);
        var boarding = boardingUtc(slot);
        return (lead > 0 && boarding != null) ? boarding - lead * 60 : null;
    }

    // Remembers which boarding time + lead has already rung, so it rings once
    function firedKey(slot as Number) as String {
        return Stops.getString(Stops.BOARDING_KEYS[slot] as String, "") + "/" + leadMinutes(slot);
    }

    function isFired(slot as Number) as Boolean {
        var v = Application.Storage.getValue("AlarmFired" + slot);
        return (v instanceof String) && v.equals(firedKey(slot));
    }

    function markFired(slot as Number) as Void {
        Application.Storage.setValue("AlarmFired" + slot, firedKey(slot));
    }

    // Cities that can have an alarm: every city of the journey except the destination
    function alarmSlots() as Array<Number> {
        var slots = Stops.activeSlots();
        return slots.slice(0, slots.size() - 1);
    }

    // The city whose alarm time has passed but whose boarding has not yet, and has not rung yet; -1 if none
    function dueSlot(nowUtc as Number) as Number {
        var slots = alarmSlots();
        for (var i = 0; i < slots.size(); i++) {
            var s = slots[i];
            var a = alarmUtc(s);
            var b = boardingUtc(s);
            if (a != null && b != null && nowUtc >= a && nowUtc < b && !isFired(s)) {
                return s;
            }
        }
        return -1;
    }

    // Registers (or clears) the background event for the earliest alarm still to come
    function schedule() as Void {
        var now = Time.now().value();
        var slots = alarmSlots();
        var best = null;
        for (var i = 0; i < slots.size(); i++) {
            var a = alarmUtc(slots[i]);
            if (a != null && a > now && !isFired(slots[i]) && (best == null || a < best)) {
                best = a;
            }
        }
        try {
            if (best == null) {
                Background.deleteTemporalEvent();
            } else {
                Background.registerForTemporalEvent(new Time.Moment(best));
            }
        } catch (e) {
            // the system refused the time (e.g. too soon after the last event); the in-app check still works
        }
    }
}

// Runs in the background when the registered alarm time arrives
(:background)
class AlarmServiceDelegate extends System.ServiceDelegate {

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var slot = Alarms.dueSlot(Time.now().value());
        if (slot >= 0) {
            Background.requestApplicationWake("Boarding in " + Alarms.leadMinutes(slot) + " min: " + Stops.label(slot));
        }
        Alarms.schedule();   // arm the next alarm
        Background.exit(null);
    }
}
