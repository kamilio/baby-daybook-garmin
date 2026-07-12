import Toybox.Lang;
import Toybox.Time;

// Shared by every (:background)-safe module that needs an epoch-millisecond
// timestamp (TokenClient, FirestoreClient, SyncQueue). Time.now() only has
// second resolution, so this is really "epoch seconds * 1000", not a true
// millisecond clock -- callers that need to disambiguate events within the
// same second (SyncQueue's queue item ids) add their own tiebreaker.
(:background)
module TimeUtil {

    (:background)
    function nowEpochMillis() as Long {
        return (Time.now().value() as Long) * 1000L;
    }

}
