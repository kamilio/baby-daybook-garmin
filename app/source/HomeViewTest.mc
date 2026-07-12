import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

// Exercises the pure geometry/hit-testing/highlight logic behind HomeView's
// tap zones and button navigation across the 240/260/280 px round display
// heights (fenix7s/fenix7/fenix7x) -- the parts that don't require a live
// touch/button event to observe. Not shipped in release builds (unit-test
// annotated).
module HomeViewTest {

    (:test)
    function testZoneBoundsTileFullHeightAndWetIsWidestAt260(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var view = new HomeView();
        view.computeZoneBounds(260);
        Storage.clearValues();

        var bottleHeight = view.zoneBottom[view.ZONE_BOTTLE] - view.zoneTop[view.ZONE_BOTTLE];
        var wetHeight = view.zoneBottom[view.ZONE_WET] - view.zoneTop[view.ZONE_WET];
        var dirtyHeight = view.zoneBottom[view.ZONE_DIRTY] - view.zoneTop[view.ZONE_DIRTY];

        return view.zoneTop[view.ZONE_BOTTLE] == 0
            && view.zoneBottom[view.ZONE_DIRTY] == 260
            && view.zoneBottom[view.ZONE_BOTTLE] == view.zoneTop[view.ZONE_WET]
            && view.zoneBottom[view.ZONE_WET] == view.zoneTop[view.ZONE_DIRTY]
            && wetHeight > bottleHeight
            && wetHeight > dirtyHeight;
    }

    (:test)
    function testZoneBoundsTileFullHeightAt240And280(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var view = new HomeView();
        Storage.clearValues();

        view.computeZoneBounds(240);
        var ok240 = view.zoneTop[view.ZONE_BOTTLE] == 0
            && view.zoneBottom[view.ZONE_BOTTLE] == view.zoneTop[view.ZONE_WET]
            && view.zoneBottom[view.ZONE_WET] == view.zoneTop[view.ZONE_DIRTY]
            && view.zoneBottom[view.ZONE_DIRTY] == 240;

        view.computeZoneBounds(280);
        var ok280 = view.zoneTop[view.ZONE_BOTTLE] == 0
            && view.zoneBottom[view.ZONE_BOTTLE] == view.zoneTop[view.ZONE_WET]
            && view.zoneBottom[view.ZONE_WET] == view.zoneTop[view.ZONE_DIRTY]
            && view.zoneBottom[view.ZONE_DIRTY] == 280;

        return ok240 && ok280;
    }

    (:test)
    function testZoneAtBoundaries(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var view = new HomeView();
        view.computeZoneBounds(260);
        Storage.clearValues();

        var bottleBottom = view.zoneBottom[view.ZONE_BOTTLE];
        var dirtyTop = view.zoneTop[view.ZONE_DIRTY];

        return view.zoneAt(0) == view.ZONE_BOTTLE
            && view.zoneAt(bottleBottom - 1) == view.ZONE_BOTTLE
            && view.zoneAt(bottleBottom) == view.ZONE_WET
            && view.zoneAt(dirtyTop - 1) == view.ZONE_WET
            && view.zoneAt(dirtyTop) == view.ZONE_DIRTY
            && view.zoneAt(259) == view.ZONE_DIRTY
            && view.zoneAt(260) == -1
            && view.zoneAt(-1) == -1;
    }

    (:test)
    function testActionZoneRoundTrip(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        var view = new HomeView();
        Storage.clearValues();

        return view.actionForZone(view.ZONE_BOTTLE).equals(Store.ACTION_BOTTLE)
            && view.actionForZone(view.ZONE_WET).equals(Store.ACTION_WET)
            && view.actionForZone(view.ZONE_DIRTY).equals(Store.ACTION_DIRTY)
            && view.zoneForAction(Store.ACTION_BOTTLE) == view.ZONE_BOTTLE
            && view.zoneForAction(Store.ACTION_WET) == view.ZONE_WET
            && view.zoneForAction(Store.ACTION_DIRTY) == view.ZONE_DIRTY
            && view.zoneForAction(null) == view.ZONE_WET
            && view.zoneForAction("garbage") == view.ZONE_WET;
    }

    (:test)
    function testInitialHighlightFollowsStoreLastAction(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastAction(Store.ACTION_DIRTY);
        var dirtyView = new HomeView();
        var dirtyOk = dirtyView.getHighlightZone() == dirtyView.ZONE_DIRTY;

        Store.setLastAction(Store.ACTION_BOTTLE);
        var bottleView = new HomeView();
        var bottleOk = bottleView.getHighlightZone() == bottleView.ZONE_BOTTLE;

        Storage.clearValues();
        var defaultView = new HomeView();
        var defaultOk = defaultView.getHighlightZone() == defaultView.ZONE_WET;

        Storage.clearValues();
        return dirtyOk && bottleOk && defaultOk;
    }

    (:test)
    function testMoveHighlightWrapsBothDirections(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setLastAction(Store.ACTION_BOTTLE);
        var view = new HomeView();
        Storage.clearValues();

        var wrapsBackward = view.getHighlightZone() == view.ZONE_BOTTLE;
        view.moveHighlight(-1);
        wrapsBackward = wrapsBackward && view.getHighlightZone() == view.ZONE_DIRTY;

        view.moveHighlight(1);
        var wrapsForward = view.getHighlightZone() == view.ZONE_BOTTLE;

        view.moveHighlight(1);
        var advancesToWet = view.getHighlightZone() == view.ZONE_WET;

        return wrapsBackward && wrapsForward && advancesToWet;
    }

}
