import Toybox.Lang;
import Toybox.WatchUi;

class SyncDiagnosticsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "Sync diagnostics" });
        addItem(new WatchUi.MenuItem("Phone sync", "Recommended · sends notification", :phone_sync, null));
        addItem(new WatchUi.MenuItem("OAuth sign-in", "Sends setup notification", :oauth, null));
        addItem(new WatchUi.MenuItem("Token refresh", "Tests Firebase authentication", :token, null));
        addItem(new WatchUi.MenuItem("Direct Firestore", "Tests Garmin header support", :firestore, null));
        addItem(new WatchUi.MenuItem("Import settings", "Reads pasted setup code", :settings, null));
        addItem(new WatchUi.MenuItem("Last result", resultText(), :result, null));
    }

    function resultText() as String {
        var diagnostic = Store.getSyncDiagnostic();
        return (diagnostic.get("stage") as String) + " · " + (diagnostic.get("code") as Number).toString();
    }
}

class SyncDiagnosticsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :phone_sync) {
            BrowserSync.request();
        } else if (id == :oauth) {
            AuthProvisioner.requestNow();
        } else if (id == :token) {
            SyncDiagnostics.testTokenRefresh();
        } else if (id == :firestore) {
            SyncDiagnostics.testFirestoreDirect();
        } else if (id == :settings) {
            var applied = SettingsProvisioner.applyFromProperties();
            Store.setSyncDiagnostic(applied ? "settings_ok" : "settings_empty", applied ? 200 : 0);
        } else if (id == :result) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            var refreshed = new SyncDiagnosticsMenu();
            WatchUi.pushView(refreshed, new SyncDiagnosticsMenuDelegate(), WatchUi.SLIDE_UP);
        }
    }

    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_DOWN); }
}

module SyncDiagnostics {
    function testTokenRefresh() as Void {
        Store.setSyncDiagnostic("token_test", 0);
        TokenClient.invalidateIdToken();
        TokenClient.getIdToken(new Lang.Method(SyncDiagnostics, :onTokenTest));
    }

    function onTokenTest(token as String?, error as Number?) as Void {
        if (token != null) {
            Store.setSyncDiagnostic("token_test_ok", 200);
        } else {
            Store.setSyncDiagnostic("token_test_failed", (error == null) ? 0 : error);
        }
    }

    function testFirestoreDirect() as Void {
        Store.setSyncDiagnostic("firestore_test_auth", 0);
        TokenClient.getIdToken(new Lang.Method(SyncDiagnostics, :onProbeToken));
    }

    function onProbeToken(token as String?, error as Number?) as Void {
        if (token == null) {
            Store.setSyncDiagnostic("firestore_test_no_token", (error == null) ? 0 : error);
            return;
        }
        FirestoreClient.probeConnection(token, new Lang.Method(SyncDiagnostics, :onFirestoreProbe));
    }

    function onFirestoreProbe(code as Number) as Void {
        Store.setSyncDiagnostic((code >= 200 && code < 300) ? "firestore_test_ok" : "firestore_test_failed", code);
    }
}
