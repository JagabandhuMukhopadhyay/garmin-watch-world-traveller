import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// (:background) because the background process also loads this class to run the boarding alarm service
(:background)
class JagaGarmin1App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
        Stops.seedDefaults();
        Alarms.schedule();
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
        Alarms.schedule();   // leave the next boarding alarm armed for when the app is closed
    }

    // Redraw (and re-arm alarms) when the user edits the route in Garmin Connect
    function onSettingsChanged() as Void {
        Alarms.schedule();
        WatchUi.requestUpdate();
    }

    // The background process that rings the boarding alarm while the app is closed
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new AlarmServiceDelegate() ];
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var view = new JagaGarmin1View();
        return [ view, new JagaGarmin1Delegate(view) ];
    }

}

function getApp() as JagaGarmin1App {
    return Application.getApp() as JagaGarmin1App;
}
