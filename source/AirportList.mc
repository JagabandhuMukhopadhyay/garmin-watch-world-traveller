import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Scrolling list of the IATA codes starting with one chosen letter: DOWN / UP step through the 3-letter codes,
// START picks the airport shown in the middle.
class AirportListView extends WatchUi.View {

    private var _data as String;   // fixed-width records of the codes starting with the chosen letter
    private var _count as Number;
    private var _idx as Number = 0;

    function initialize(letter as Number, code as String) {
        View.initialize();
        _data = Airports.chunk(letter);
        _count = Airports.count(_data);
        for (var i = 0; i < _count; i++) {
            if (Airports.codeAt(_data, i).equals(code.toUpper())) {
                _idx = i;
                break;
            }
        }
    }

    // Move by one code, wrapping round within this letter
    function step(dir as Number) as Void {
        _idx = (_idx + dir + _count) % _count;
        WatchUi.requestUpdate();
    }

    function currentCode() as String {
        return Airports.codeAt(_data, _idx);
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var sideFont = Graphics.FONT_XTINY;
        var sideH = dc.getFontHeight(sideFont);
        var codeFont = Graphics.FONT_MEDIUM;
        var codeH = dc.getFontHeight(codeFont);

        // Selected block (code + city) centred on the screen; the neighbouring codes are stacked above and below it,
        // each in its own row so they never run into the selected block
        var top = cy - (codeH + sideH) / 2;
        var bottom = top + codeH + sideH;
        var gap = 4;
        for (var d = -2; d <= 2; d++) {
            var at = _idx + d;
            if (d == 0 || at < 0 || at >= _count) {
                continue;
            }
            var y = d < 0 ? top - gap - (-d) * (sideH + gap) + gap : bottom + gap + (d - 1) * (sideH + gap);
            dc.setColor(d == -2 || d == 2 ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, sideFont, Airports.codeAt(_data, at) + "  " + Airports.nameAt(_data, at),
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top, codeFont, currentCode(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, top + codeH, sideFont, Airports.nameAt(_data, _idx), Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class AirportListInputDelegate extends WatchUi.BehaviorDelegate {

    private var _view as AirportListView;
    private var _stop as Number;

    function initialize(view as AirportListView, stop as Number) {
        BehaviorDelegate.initialize();
        _view = view;
        _stop = stop;
    }

    function onNextPage() as Boolean {
        _view.step(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.step(-1);
        return true;
    }

    function onSelect() as Boolean {
        var code = _view.currentCode();
        Application.Properties.setValue(Stops.CODE_KEYS[_stop] as String, code);
        var city = Airports.cityFor(code);
        if (city != null) {
            Application.Properties.setValue(Stops.LABEL_KEYS[_stop] as String, city);
        }
        StopMenu.closeAll(2);   // this list + the stop menu beneath it
        return true;
    }
}
