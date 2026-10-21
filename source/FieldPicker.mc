import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Multi-field picker that shows all its fields side by side on ONE screen (the stock Garmin Picker steps through
// its columns one screen at a time on the fr965). UP/DOWN change the highlighted field, START moves to the next
// field and, on the last one, saves; BACK moves to the previous field and, on the first one, cancels.
// A tap on a field highlights it.
class FieldPickerView extends WatchUi.View {

    private var _title as String;
    private var _subtitle as String?;
    private var _labels as Array<Array<String> >;
    private var _values as Array<Array<Number> >;
    private var _index as Array<Number>;
    private var _separators as Array<String>;   // separators[i] is drawn between field i and field i + 1
    private var _active as Number = 0;

    function initialize(title as String, subtitle as String?, labels as Array<Array<String> >,
            values as Array<Array<Number> >, defaults as Array<Number>, separators as Array<String>) {
        View.initialize();
        _title = title;
        _subtitle = subtitle;
        _labels = labels;
        _values = values;
        _index = defaults;
        _separators = separators;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        // Title, and under it the details chosen in the previous step (e.g. the date) in blue.
        // Each uses the largest font that fits within the width of the round screen near the top.
        var textW = w * 66 / 100;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 9 / 100, fitFont(dc, _title, textW, [Graphics.FONT_TINY, Graphics.FONT_XTINY]),
            _title, Graphics.TEXT_JUSTIFY_CENTER);
        if (_subtitle != null) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 20 / 100, fitFont(dc, _subtitle as String, textW,
                [Graphics.FONT_TINY, Graphics.FONT_XTINY]), _subtitle as String, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Fields side by side; the highlighted one is white with arrows above and below. One font for all fields:
        // the largest whose widest label fits its column.
        var colW = w * 70 / 100 / _labels.size();
        var widest = "";
        for (var i = 0; i < _labels.size(); i++) {
            var list = _labels[i] as Array<String>;
            for (var j = 0; j < list.size(); j++) {
                if (list[j].length() > widest.length()) {
                    widest = list[j];
                }
            }
        }
        var font = fitFont(dc, widest, colW - 6, [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        var fontH = dc.getFontHeight(font);
        var cy = h * 55 / 100;
        for (var i = 0; i < _labels.size(); i++) {
            var cx = columnCenter(i, w);
            var active = (i == _active);
            dc.setColor(active ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, font, (_labels[i] as Array<String>)[_index[i]],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            if (active) {
                var a = w * 3 / 100;
                var up = cy - fontH / 2 - a * 2;
                var down = cy + fontH / 2 + a * 2;
                dc.fillPolygon([[cx - a, up + a], [cx + a, up + a], [cx, up - a]]);
                dc.fillPolygon([[cx - a, down - a], [cx + a, down - a], [cx, down + a]]);
            }
            if (i < _separators.size() && _separators[i].length() > 0) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText((cx + columnCenter(i + 1, w)) / 2, cy, font, _separators[i],
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        // What START does now
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 80 / 100, Graphics.FONT_XTINY,
            _active < _labels.size() - 1 ? "START: next" : "START: save", Graphics.TEXT_JUSTIFY_CENTER);

        // Green tick beside the START/STOP button (upper right)
        var s = w * 4 / 100;
        var x = w * 86 / 100;
        var y = h * 30 / 100;
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(6);
        dc.drawLine(x - s, y, x - s / 3, y + s * 2 / 3);
        dc.drawLine(x - s / 3, y + s * 2 / 3, x + s, y - s * 2 / 3);
        dc.setPenWidth(1);
    }

    // The first font of `fonts` (largest first) in which `text` is at most `maxW` wide; the last one if none fit
    private function fitFont(dc as Dc, text as String, maxW as Number, fonts as Array<FontType>) as FontType {
        for (var i = 0; i < fonts.size() - 1; i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxW) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    // Centre x of field i: the fields share the middle 70% of the screen width
    private function columnCenter(i as Number, w as Number) as Number {
        var colW = w * 70 / 100 / _labels.size();
        return (w - colW * _labels.size()) / 2 + colW * i + colW / 2;
    }

    // UP / DOWN: change the highlighted field, wrapping round
    function step(delta as Number) as Void {
        var size = (_labels[_active] as Array<String>).size();
        _index[_active] = (_index[_active] + delta + size) % size;
        WatchUi.requestUpdate();
    }

    // START: highlight the next field. Returns true when the last field has been confirmed.
    function advance() as Boolean {
        if (_active < _labels.size() - 1) {
            _active++;
            WatchUi.requestUpdate();
            return false;
        }
        return true;
    }

    // BACK: highlight the previous field. Returns true when already on the first field (= cancel).
    function retreat() as Boolean {
        if (_active > 0) {
            _active--;
            WatchUi.requestUpdate();
            return false;
        }
        return true;
    }

    function selectAt(x as Number, w as Number) as Void {
        var colW = w * 70 / 100 / _labels.size();
        var i = (x - (w - colW * _labels.size()) / 2) / colW;
        if (x >= (w - colW * _labels.size()) / 2 && i >= 0 && i < _labels.size()) {
            _active = i;
            WatchUi.requestUpdate();
        }
    }

    function selectedValues() as Array<Number> {
        var result = [] as Array<Number>;
        for (var i = 0; i < _values.size(); i++) {
            result.add((_values[i] as Array<Number>)[_index[i]]);
        }
        return result;
    }
}

class FieldPickerDelegate extends WatchUi.BehaviorDelegate {

    private var _view as FieldPickerView;
    private var _handler;   // object with onAccept(values) and onCancel()

    function initialize(view as FieldPickerView, handler) {
        BehaviorDelegate.initialize();
        _view = view;
        _handler = handler;
    }

    function onNextPage() as Boolean {         // DOWN button, swipe up
        _view.step(1);
        return true;
    }

    function onPreviousPage() as Boolean {     // UP button, swipe down
        _view.step(-1);
        return true;
    }

    function onSelect() as Boolean {           // START button
        if (_view.advance()) {
            _handler.onAccept(_view.selectedValues());
        }
        return true;
    }

    function onBack() as Boolean {             // BACK button
        if (_view.retreat()) {
            _handler.onCancel();
        }
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        _view.selectAt((clickEvent.getCoordinates() as Array<Number>)[0], System.getDeviceSettings().screenWidth);
        return true;
    }
}
