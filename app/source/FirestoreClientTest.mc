import Toybox.Lang;
import Toybox.Test;

// Exercises the parts of FirestoreClient.mc that don't require a live
// network round trip: request-body field encoding (per docs/wire-format.md)
// for both event types, and the response status-code classification. The
// commit HTTP round trip itself (Communications.makeWebRequest) is
// exercised in the simulator, not here. Not shipped in release builds
// (unit-test annotated).
module FirestoreClientTest {

    (:test)
    function testBuildRequestBodyBottleWithVolumeUsesDoubleValue(logger as Test.Logger) as Boolean {
        var event = { "id" => "1720261201154-1", "type" => "bottle", "startMillis" => 1720261201154l, "volume" => 120 };
        var body = FirestoreClient.buildRequestBody(event, "user-1", "baby-1", 1720261201200l);
        var fields = body.get("writes")[0].get("update").get("fields");
        return fields.get("volume").get("doubleValue") == 120.0d;
    }

    (:test)
    function testBuildRequestBodyBottleWithoutVolumeOmitsField(logger as Test.Logger) as Boolean {
        var event = { "id" => "1720261201154-1", "type" => "bottle", "startMillis" => 1720261201154l };
        var body = FirestoreClient.buildRequestBody(event, "user-1", "baby-1", 1720261201200l);
        var fields = body.get("writes")[0].get("update").get("fields");
        return !fields.hasKey("volume");
    }

    (:test)
    function testBuildRequestBodyDiaperChangeEncodesPeeAndPooAsIntegerValue(logger as Test.Logger) as Boolean {
        var event = { "id" => "1720261201154-2", "type" => "diaper_change", "startMillis" => 1720261201154l, "pee" => true, "poo" => false };
        var body = FirestoreClient.buildRequestBody(event, "user-1", "baby-1", 1720261201200l);
        var fields = body.get("writes")[0].get("update").get("fields");
        return fields.get("pee").get("integerValue").equals("1")
            && fields.get("poo").get("integerValue").equals("0");
    }

    (:test)
    function testBuildRequestBodyDiaperChangeDirtyOnly(logger as Test.Logger) as Boolean {
        var event = { "id" => "1720261201154-3", "type" => "diaper_change", "startMillis" => 1720261201154l, "pee" => false, "poo" => true };
        var body = FirestoreClient.buildRequestBody(event, "user-1", "baby-1", 1720261201200l);
        var fields = body.get("writes")[0].get("update").get("fields");
        return fields.get("pee").get("integerValue").equals("0")
            && fields.get("poo").get("integerValue").equals("1");
    }

    (:test)
    function testBuildRequestBodyCommonFieldsAndDocumentName(logger as Test.Logger) as Boolean {
        var event = { "id" => "the-uid", "type" => "bottle", "startMillis" => 1720261201154l };
        var body = FirestoreClient.buildRequestBody(event, "user-42", "baby-7", 1720261201200l);
        var write = body.get("writes")[0];
        var update = write.get("update");
        var fields = update.get("fields");
        var transforms = write.get("updateTransforms");

        var nameOk = update.get("name").equals("projects/baby-daybook-app/databases/(default)/documents/babyData/babyUid_baby-7/dailyActions/the-uid");
        var fieldsOk = fields.get("uid").get("stringValue").equals("the-uid")
            && fields.get("userUid").get("stringValue").equals("user-42")
            && fields.get("babyUid").get("stringValue").equals("baby-7")
            && fields.get("type").get("stringValue").equals("bottle")
            && fields.get("startMillis").get("integerValue").equals("1720261201154")
            && fields.get("updatedMillis").get("integerValue").equals("1720261201200")
            && fields.get("inProgress").get("booleanValue") == false;
        var transformOk = transforms.size() == 1
            && transforms[0].get("fieldPath").equals("svt")
            && transforms[0].get("setToServerValue").equals("REQUEST_TIME");

        return nameOk && fieldsOk && transformOk;
    }

    (:test)
    function testClassifyResponseOkFor2xxRange(logger as Test.Logger) as Boolean {
        return FirestoreClient.classifyResponse(200) == FirestoreClient.OK
            && FirestoreClient.classifyResponse(201) == FirestoreClient.OK
            && FirestoreClient.classifyResponse(299) == FirestoreClient.OK;
    }

    (:test)
    function testClassifyResponseUnauthenticatedFor401(logger as Test.Logger) as Boolean {
        return FirestoreClient.classifyResponse(401) == FirestoreClient.UNAUTHENTICATED;
    }

    (:test)
    function testClassifyResponsePermanentFor400And403(logger as Test.Logger) as Boolean {
        return FirestoreClient.classifyResponse(400) == FirestoreClient.PERMANENT
            && FirestoreClient.classifyResponse(403) == FirestoreClient.PERMANENT;
    }

    (:test)
    function testClassifyResponseRetryableForEverythingElse(logger as Test.Logger) as Boolean {
        return FirestoreClient.classifyResponse(500) == FirestoreClient.RETRYABLE
            && FirestoreClient.classifyResponse(404) == FirestoreClient.RETRYABLE
            && FirestoreClient.classifyResponse(-104) == FirestoreClient.RETRYABLE;
    }

}
