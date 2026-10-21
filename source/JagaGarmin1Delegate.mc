import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Button map (Garmin convention): START = select / open menu, UP and DOWN = move between cities, BACK = exit.
class JagaGarmin1Delegate extends WatchUi.BehaviorDelegate {

    private var _view as JagaGarmin1View;

    function initialize(view as JagaGarmin1View) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // START button (or a screen tap): dismisses a boarding alarm banner if one is showing, otherwise opens the
    // menu for the city in focus
    function onSelect() as Boolean {
        if (!_view.dismissAlert()) {
            StopMenu.open(Stops.focusIndex());
        }
        return true;
    }

    // DOWN button: next city in the ring
    function onNextPage() as Boolean {
        moveFocus(1);
        return true;
    }

    // UP button: previous city in the ring
    function onPreviousPage() as Boolean {
        moveFocus(-1);
        return true;
    }

    private function moveFocus(step as Number) as Void {
        Stops.moveFocus(step);
        WatchUi.requestUpdate();
    }
}
