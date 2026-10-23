import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class JagaGarmin1View extends WatchUi.View {

    // Kept from the watch-face version: dimmed colours are only used if this is ever set (watch apps never sleep-dim)
    private var _lowPower as Boolean = false;

    private var _timer as Timer.Timer? = null;

    // Boarding alarm banner: text to show and the UTC second it disappears at
    private var _alertCity as String = "";
    private var _alertLine as String = "";
    private var _alertUntil as Number = 0;

    function initialize() {
        View.initialize();
    }

    // Redraw every second so the aeroplane can blink; the clocks and flown/remaining meters stay current too
    function onShow() as Void {
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onTick), 1000, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        checkBoardingAlarm();
        WatchUi.requestUpdate();
    }

    // Rings the boarding alarm (vibration, beep, banner) once its time has come while the app is open
    private function checkBoardingAlarm() as Void {
        var now = Time.now().value();
        var slot = Alarms.dueSlot(now);
        if (slot < 0) {
            return;
        }
        Alarms.markFired(slot);
        _alertLine = "Boarding in " + Alarms.leadMinutes(slot) + " min";
        _alertCity = Stops.display(slot);
        _alertUntil = now + 60;

        if (Attention has :vibrate) {
            var on = new Attention.VibeProfile(100, 500);
            var off = new Attention.VibeProfile(0, 200);
            Attention.vibrate([on, off, on, off, on]);
        }
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALARM);
        }
    }

    // START dismisses the banner. Returns true if a banner was showing.
    function dismissAlert() as Boolean {
        if (Time.now().value() < _alertUntil) {
            _alertUntil = 0;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

    // Red banner over the middle of the screen while an alarm is active
    private function drawAlert(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var boxW = w * 80 / 100;
        var boxH = h * 28 / 100;
        var x = (w - boxW) / 2;
        var y = (h - boxH) / 2;
        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, boxW, boxH, 16);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, y + boxH * 28 / 100, Graphics.FONT_SMALL, _alertLine,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w / 2, y + boxH * 70 / 100, Graphics.FONT_MEDIUM, _alertCity,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var nowUtc = Time.now().value();
        // One row per city of the journey (3 with one plane change, 4 with two), in travel order:
        // [slot id, label key, offset key, boarding key, flight-minutes key of the leg leaving this city]
        var slots = Stops.activeSlots();
        var rows = [] as Array<Array>;
        for (var s = 0; s < slots.size(); s++) {
            var slot = slots[s];
            rows.add([slot, Stops.LABEL_KEYS[slot], Stops.OFFSET_KEYS[slot], Stops.BOARDING_KEYS[slot],
                Stops.FLIGHT_KEYS[slot]]);
        }

        var width = dc.getWidth();
        var height = dc.getHeight();
        var labelFont = Graphics.FONT_XTINY;
        var margin = height * 6 / 100;

        // The cities form a ring (Origin > Change 1 > [Change 2 >] Destination > Origin). The focus city is drawn
        // in the middle, the previous city above it and the next city below it: always three blocks on screen.
        var count = rows.size();
        var blocks = 3;
        var focus = slots.indexOf(Stops.focusIndex());   // position of the focus city in the journey
        var order = [(focus + count - 1) % count, focus, (focus + 1) % count] as Array<Number>;

        // Pick the largest [focus, other] time font pair whose three blocks fit with a small gap between them
        // Focus block = label line + big time + boarding line. Other blocks = one "label time" line.
        var fontPairs = [
            [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_SMALL],
            [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_TINY],
            [Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_XTINY],
            [Graphics.FONT_NUMBER_MILD, Graphics.FONT_XTINY],
            [Graphics.FONT_MEDIUM, Graphics.FONT_XTINY]
        ];
        var labelH = dc.getFontHeight(labelFont);

        // City tag (START / CH1 / CH2 / DEST) above each place name, in a very small scalable font
        var tagVector = Graphics.getVectorFont({ :face => ["RobotoCondensedRegular", "RobotoRegular"], :size => 16 });
        var tagFont = tagVector != null ? tagVector : labelFont;
        var tagH = dc.getFontHeight(tagFont);

        var captionFont = Graphics.getVectorFont({ :face => ["RobotoCondensedRegular", "RobotoRegular"], :size => 20 });
        var focusFont = fontPairs[fontPairs.size() - 1][0];
        var otherFont = fontPairs[fontPairs.size() - 1][1];
        var focusH = 0;
        var otherH = 0;
        var gap = 0;
        for (var f = 0; f < fontPairs.size(); f++) {
            focusFont = fontPairs[f][0];
            otherFont = fontPairs[f][1];
            focusH = tagH + 2 * labelH + dc.getFontHeight(focusFont) - 2 * focusPull(dc.getFontHeight(focusFont));
            otherH = tagH + labelH + dc.getFontHeight(otherFont);   // tag + name line + time line
            gap = (height - 2 * margin - focusH - 2 * otherH) / (blocks - 1);

            // The side lines (name, and "h:mma") must also fit the width of the round screen near the top/bottom
            var widest = dc.getTextWidthInPixels("12:00p", otherFont);
            for (var i = 0; i < count; i++) {
                var w = dc.getTextWidthInPixels(Stops.display((rows[i] as Array)[0] as Number), labelFont);
                widest = w > widest ? w : widest;
            }
            // The Flown / Remaining rings sit either side of the big time, so the time must be narrow enough
            // for the rings (and the wider "Remaining" caption) to stay on the round screen
            var focusFontH = dc.getFontHeight(focusFont);
            var ringR = (focusFontH - 2 * focusPull(focusFontH)) / 2;
            var timeW = dc.getTextWidthInPixels("12:00", focusFont) + dc.getTextWidthInPixels("p", labelFont);
            var capW = dc.getTextWidthInPixels("Remaining", captionFont != null ? captionFont : labelFont);
            var ringReach = timeW / 2 + ringR + 8 + (capW / 2 > ringR ? capW / 2 : ringR);
            var ringsFit = ringReach <= width / 2 - width * 3 / 100;

            if (gap >= 4 && widest <= width * 60 / 100 && ringsFit) {
                break;
            }
        }

        // Origin has no offset key: it uses the watch's own local time zone (DST included)
        var offsets = [] as Array<Number>;
        for (var i = 0; i < rows.size(); i++) {
            offsets.add(Stops.offsetMin((rows[i] as Array)[0] as Number));
        }

        // Boarding string per stop exactly as entered ("" = not set: no BRD / RCH shown for that airport)
        var boardings = [] as Array<String>;
        for (var i = 0; i < rows.size(); i++) {
            var key = (rows[i] as Array)[3];
            boardings.add(key == null ? "" : Stops.getString(key as String, ""));
        }

        var y = margin;
        for (var pos = 0; pos < blocks; pos++) {
            var i = order[pos];
            var row = rows[i] as Array;
            var isFocus = (pos == 1);
            var blockH = isFocus ? focusH : otherH;
            // The flight leaving this stop lands in the next stop's time zone
            var nextOffset = offsets[(i + 1) % count];
            // Flight shown by the gauges: the focus stop's own departing flight, or for the last stop
            // (no departure) the flight that brought the traveller there. The clock starts when the
            // flight is started with the START button; until then it shows 0 flown.
            // The last city of the journey is the destination: no BRD / RCH line, rings or aeroplane for it,
            // even when it is the focus city
            var slotId = row[0] as Number;
            var isDest = (i == count - 1);
            var legStart = null;
            var legMinutes = 0;
            if (isFocus && !isDest) {
                legStart = Stops.flightStart(slotId);
                legMinutes = Stops.flightMinutes(slotId);
            }
            // With the Origin in focus there is nothing above it (the ring would show DEST there)
            var blankTop = (pos == 0 && focus == 0);
            if (!blankTop) {
                drawRow(dc, width / 2, y, labelFont, isFocus ? focusFont : otherFont, isFocus, nowUtc,
                    Stops.display(slotId),
                    Stops.tagFor(i, count), tagFont,
                    offsets[i], nextOffset, isDest ? "" : boardings[i], Stops.flightMinutes(slotId), legStart, legMinutes);
            }

            // Separator line between this block and the next
            if (pos < blocks - 1 && !blankTop) {
                var lineY = y + blockH + gap / 2;
                dc.setColor(_lowPower ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(width * 25 / 100, lineY, width * 75 / 100, lineY);
            }
            y += blockH + gap;
        }

        if (Time.now().value() < _alertUntil) {
            drawAlert(dc);
        }
    }

    // Draws one block: label, local time of that location, then "BRD hh:mm" (red) and "RCH hh:mm" (green).
    private function drawRow(dc as Dc, cx as Number, y as Number, labelFont as FontType,
            timeFont as FontType, isFocus as Boolean, nowUtc as Number, label as String,
            tag as String, tagFont as FontType,
            offsetMin as Number, nextOffsetMin as Number, boarding as String,
            travelMin as Number, legStartUtc as Number?, legMin as Number) as Void {
        // Shift "now" by the zone offset; reading it back with utcInfo gives that zone's wall clock.
        var localSecs = nowUtc + offsetMin * 60;
        var info = Gregorian.utcInfo(new Time.Moment(localSecs), Time.FORMAT_SHORT);

        var labelColor = _lowPower ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY;
        var boardingText = "";
        var reachText = "";
        var boardingColor = Graphics.COLOR_RED;
        var reachColor = Graphics.COLOR_GREEN;
        var boardingTime = Stops.parseBoarding(boarding);
        if (boardingTime != null) {
            var passed = boardingTime < localSecs;
            var sameDay = boarding.substring(0, 10).equals(
                Lang.format("$1$-$2$-$3$", [info.year, info.month.format("%02d"), info.day.format("%02d")]));
            var boardClock = Stops.clock12(boarding.substring(11, 13).toNumber() as Number,
                boarding.substring(14, 16).toNumber() as Number);
            var when = sameDay ? boardClock : boarding.substring(5, 10) + " " + boardClock;
            boardingText = "BRD " + when;

            // Reach time: boarding instant + flight time, shown in the next stop's local time
            var reachLocal = boardingTime - offsetMin * 60 + travelMin * 60 + nextOffsetMin * 60;
            var r = Gregorian.utcInfo(new Time.Moment(reachLocal), Time.FORMAT_SHORT);
            var dayDelta = reachLocal / 86400 - boardingTime / 86400;
            if (travelMin > 0) {   // no RCH until a flight time is set
                reachText = "RCH " + Stops.clock12(r.hour, r.min);
                if (dayDelta != 0) {
                    reachText += (dayDelta > 0 ? "+" : "") + dayDelta.format("%d");
                }
            }

            if (passed) {
                boardingColor = Graphics.COLOR_DK_GRAY;
                reachColor = Graphics.COLOR_DK_GRAY;
            } else if (_lowPower) {
                boardingColor = Graphics.COLOR_DK_RED;
                reachColor = Graphics.COLOR_DK_GREEN;
            }
        }

        // Role tag on top; everything else in the block starts below it
        dc.setColor(_lowPower ? Graphics.COLOR_DK_BLUE : Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, tagFont, tag, Graphics.TEXT_JUSTIFY_CENTER);
        y += dc.getFontHeight(tagFont);

        var labelH = dc.getFontHeight(labelFont);
        var timeColor =_lowPower ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_WHITE;
        var lineY;   // top of the boarding/reach line

        if (isFocus) {
            // Label on top, large local time in the middle, boarding line below
            dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, labelFont, label, Graphics.TEXT_JUSTIFY_CENTER);

            // Small aeroplane just left of the START / CH1 tag (clear of the Flown ring): steady red while the flight
            // has not been started, blinking green (on every other second) once it is under way
            if (legMin > 0) {
                var started = legStartUtc != null;
                if (!started || nowUtc % 2 == 0) {
                    var tagH = dc.getFontHeight(tagFont);
                    var planeS = tagH / 3;
                    drawPlane(dc, cx - dc.getTextWidthInPixels(tag, tagFont) / 2 - planeS - 6, y - tagH / 2,
                        planeS, started ? Graphics.COLOR_GREEN : Graphics.COLOR_RED);
                }
            }

            // Number fonts have no letters, so draw the digits large and the a/p marker in the small font beside them
            var timeH = dc.getFontHeight(timeFont);
            var pull = focusPull(timeH);   // number fonts carry empty space above/below the digits; tighten it
            var timeY = y + labelH - pull;
            var digits = Lang.format("$1$:$2$", [Stops.hour12(info.hour), info.min.format("%02d")]);
            var marker = info.hour < 12 ? "a" : "p";
            var digitsW = dc.getTextWidthInPixels(digits, timeFont);
            var markerW = dc.getTextWidthInPixels(marker, labelFont);
            var timeLeft = cx - (digitsW + markerW) / 2;
            dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(timeLeft, timeY, timeFont, digits, Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(timeLeft + digitsW, timeY + timeH - labelH - timeH / 10, labelFont, marker,
                Graphics.TEXT_JUSTIFY_LEFT);
            lineY = timeY + timeH - pull;

            // Flown gauge on the left of the time, remaining gauge on the right
            if (legMin > 0) {
                var totalSecs = legMin * 60;
                var elapsed = legStartUtc == null ? 0 : nowUtc - legStartUtc;
                elapsed = elapsed < 0 ? 0 : (elapsed > totalSecs ? totalSecs : elapsed);
                var r = (timeH - 2 * pull) / 2;
                // Raised by one text line so the caption below each ring still sits inside this block
                var gy = timeY + timeH / 2 - labelH;
                var dx = (digitsW + markerW) / 2 + r + 8;
                drawGauge(dc, cx - dx, gy, r, elapsed.toFloat() / totalSecs, Graphics.COLOR_BLUE,
                    (elapsed / 3600.0).format("%.1f"), "Flown", labelFont);
                drawGauge(dc, cx + dx, gy, r, (totalSecs - elapsed).toFloat() / totalSecs, Graphics.COLOR_ORANGE,
                    ((totalSecs - elapsed) / 3600.0).format("%.1f"), "Remaining", labelFont);            }
        } else {
            // Compact: place name on one line, "h:mma" on the line below (timeFont is a regular font here, so it can draw the a/p)
            dc.setColor(labelColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, labelFont, label, Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y + labelH, timeFont, Stops.clock12(info.hour, info.min), Graphics.TEXT_JUSTIFY_CENTER);
            lineY = y + labelH + dc.getFontHeight(timeFont);
        }

        // Only the focus (middle) stop shows its boarding and reach times
        if (isFocus && boardingText.length() > 0) {
            // Boarding (red) and reach (green) side by side, centred together
            var spacer = "  ";
            var boardW = dc.getTextWidthInPixels(boardingText + (reachText.length() > 0 ? spacer : ""), labelFont);
            var reachW = dc.getTextWidthInPixels(reachText, labelFont);
            var left = cx - (boardW + reachW) / 2;
            dc.setColor(boardingColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left, lineY, labelFont, boardingText, Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(reachColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(left + boardW, lineY, labelFont, reachText, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // Top-down aeroplane silhouette pointing right (towards the remaining ring), `s` = half its length in pixels
    private function drawPlane(dc as Dc, x as Number, y as Number, s as Number, color as ColorType) as Void {
        // Outline of the upper half, nose first (unit coordinates, +x = forward, -y = up); the lower half mirrors it
        var half = [[1.0, 0.0], [0.35, -0.18], [-0.05, -0.95], [-0.30, -0.95], [-0.05, -0.15],
            [-0.65, -0.12], [-0.85, -0.45], [-1.0, -0.45], [-0.95, 0.0]];
        var points = [] as Array<[Number, Number]>;
        for (var i = 0; i < half.size(); i++) {
            var p = half[i] as Array<Float>;
            points.add([x + (p[0] * s).toNumber(), y + (p[1] * s).toNumber()]);
        }
        for (var i = half.size() - 2; i >= 1; i--) {
            var p = half[i] as Array<Float>;
            points.add([x + (p[0] * s).toNumber(), y - (p[1] * s).toNumber()]);
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(points);
    }

    // Round meter: grey track, coloured arc from 12 o'clock clockwise covering `fraction` of the circle,
    // and the hours value in the middle.
    private function drawGauge(dc as Dc, x as Number, y as Number, r as Number, fraction as Float,
            color as ColorType, hoursText as String, caption as String, font as FontType) as Void {
        var pen = 5;
        var arcR = r - pen / 2;
        dc.setPenWidth(pen);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, arcR);

        var sweep = (fraction * 360).toNumber();
        if (!_lowPower && sweep > 0) {
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            if (sweep >= 360) {
                dc.drawCircle(x, y, arcR);
            } else {
                dc.drawArc(x, y, arcR, Graphics.ARC_CLOCKWISE, 90, ((90 - sweep) % 360 + 360) % 360);
            }
        }
        dc.setPenWidth(1);

        dc.setColor(_lowPower ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, hoursText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Caption just below the ring
        dc.setColor(_lowPower ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        // XTINY is the smallest built-in font, so use a scalable font for a smaller caption (falls back to XTINY)
        var captionFont = Graphics.getVectorFont({ :face => ["RobotoCondensedRegular", "RobotoRegular"], :size => 20 });
        dc.drawText(x, y + r, captionFont != null ? captionFont : font, caption, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Space trimmed from each side of the focus time line to close the gaps to the label and boarding lines
    private function focusPull(timeFontHeight as Number) as Number {
        return timeFontHeight / 6;
    }


}
