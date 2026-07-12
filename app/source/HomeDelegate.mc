import Toybox.Lang;
import Toybox.WatchUi;

// Input for HomeView: tap hit-tests against the view's zone geometry;
// Up/Down (onPreviousPage/onNextPage) move the highlight ring for
// water-lock/gloves use, START (onSelect) activates the highlighted zone,
// BACK exits. Holds the HomeView instance directly (rather than
// WatchUi.getCurrentView()) so hit-testing and highlight movement always
// operate on the exact geometry that was last drawn.
class HomeDelegate extends WatchUi.BehaviorDelegate {

    var view as HomeView;

    function initialize(homeView as HomeView) {
        BehaviorDelegate.initialize();
        view = homeView;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coordinates = clickEvent.getCoordinates();
        var zone = view.zoneAt(coordinates[1]);
        if (zone >= 0) {
            activate(zone);
        }
        return true;
    }

    function onNextPage() as Boolean {
        view.moveHighlight(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        view.moveHighlight(-1);
        return true;
    }

    function onSelect() as Boolean {
        activate(view.getHighlightZone());
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    // Persists Store.lastAction on every activation -- including Bottle,
    // whose actual record only happens if the confirm screen it pushes is
    // then confirmed -- so the highlight survives even an abandoned bottle
    // flow.
    function activate(zone as Number) as Void {
        var action = view.actionForZone(zone);
        Store.setLastAction(action);

        if (zone == view.ZONE_BOTTLE) {
            WatchUi.pushView(new BottleConfirmView(), new BottleConfirmDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else {
            RecordController.recordDiaper(action);
        }
    }

}
