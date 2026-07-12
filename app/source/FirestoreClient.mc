import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;

// Firestore documents:commit client for the single write this app makes:
// upserting babyData/babyUid_<BABY>/dailyActions/<uid> for a bottle or
// diaper_change event. The event's queue id doubles as the Firestore
// document id, so retries upsert the same document -- idempotent by
// construction. Field encoding mirrors docs/wire-format.md, verified
// against the real account (notably: volume is always doubleValue, and
// pee/poo are integerValue 0/1, not Firestore's native booleanValue).
// No UI imports: this module must stay safe to pull into the (:background)
// build, where the background sync service commits queued events directly.
(:background)
module FirestoreClient {

    const COMMIT_URL = "https://firestore.googleapis.com/v1/projects/baby-daybook-app/databases/(default)/documents:commit";
    const DOCUMENT_PATH_PREFIX = "projects/baby-daybook-app/databases/(default)/documents/babyData/babyUid_";

    // Status classes reported to commitEvent's callback in place of the raw
    // HTTP response code.
    const OK = 0;
    const UNAUTHENTICATED = 1;
    const PERMANENT = 2;
    const RETRYABLE = 3;

    // Callback stashed for the in-flight request -- Communications.makeWebRequest
    // requires a fixed-signature Method, so per-call context can't be
    // captured directly. Callers (SyncQueue) keep a single commit in flight
    // at a time, so one module variable is enough; a second concurrent
    // commitEvent() call would clobber it and is not a supported use.
    (:background)
    var pendingCallback = null as Method?;

    (:background)
    function commitEvent(event as Dictionary, idToken as String, callback as Method(status as Number) as Void) as Void {
        pendingCallback = callback;

        var body = buildRequestBody(event, TokenClient.getUserId(), Config.getBabyUid(), nowEpochMillis());
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Content-Type" => "application/json",
                "Authorization" => "Bearer " + idToken
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(COMMIT_URL, body, options, new Lang.Method(FirestoreClient, :onCommitResponse));
    }

    (:background)
    function onCommitResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        var callback = pendingCallback;
        pendingCallback = null as Method?;
        if (callback != null) {
            callback.invoke(classifyResponse(responseCode));
        }
    }

    // Pure status-code classification, split out for testability.
    (:background)
    function classifyResponse(responseCode as Number) as Number {
        if (responseCode >= 200 && responseCode < 300) {
            return OK;
        }
        if (responseCode == 401) {
            return UNAUTHENTICATED;
        }
        if (responseCode == 400 || responseCode == 403) {
            return PERMANENT;
        }
        return RETRYABLE;
    }

    // Builds the documents:commit request body for one event. Pure aside
    // from its inputs, so it's directly testable without a network call.
    // event is expected to carry "id" (also the document id), "type"
    // ("bottle" or "diaper_change"), "startMillis", and action-specific
    // fields ("volume" for bottle, "pee"/"poo" for diaper_change).
    (:background)
    function buildRequestBody(event as Dictionary, userUid as String, babyUid as String, nowMillis as Numeric) as Dictionary {
        var uid = event.get("id") as String;
        var type = event.get("type") as String;
        var startMillis = event.get("startMillis") as Numeric;

        var fields = {
            "uid" => stringValue(uid),
            "userUid" => stringValue(userUid),
            "babyUid" => stringValue(babyUid),
            "type" => stringValue(type),
            "startMillis" => integerValue(startMillis),
            "updatedMillis" => integerValue(nowMillis),
            "inProgress" => { "booleanValue" => false }
        };

        if (type.equals("bottle")) {
            var volume = event.get("volume");
            if (volume != null) {
                fields.put("volume", { "doubleValue" => (volume as Numeric).toDouble() });
            }
        } else if (type.equals("diaper_change")) {
            fields.put("pee", integerValue(boolToInt(event.get("pee") == true)));
            fields.put("poo", integerValue(boolToInt(event.get("poo") == true)));
        }

        return {
            "writes" => [{
                "update" => {
                    "name" => DOCUMENT_PATH_PREFIX + babyUid + "/dailyActions/" + uid,
                    "fields" => fields
                },
                "updateTransforms" => [
                    { "fieldPath" => "svt", "setToServerValue" => "REQUEST_TIME" }
                ]
            }]
        };
    }

    (:background)
    function stringValue(value as String) as Dictionary {
        return { "stringValue" => value };
    }

    // integerValue is a JSON string on the wire, not a number.
    (:background)
    function integerValue(value as Numeric) as Dictionary {
        return { "integerValue" => value.toString() };
    }

    (:background)
    function boolToInt(value as Boolean) as Number {
        return value ? 1 : 0;
    }

    (:background)
    function nowEpochMillis() as Long {
        return (Time.now().value() as Long) * 1000L;
    }

}
