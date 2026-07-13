import Toybox.Lang;

// Offline-first heart of the app: every recorded action lands in
// Store.syncQueue before any network I/O, and this module is the only
// thing that ever drains it. One HTTP round trip is ever in flight at a
// time (TokenClient.getIdToken -> FirestoreClient.commitEvent), oldest
// item first, and a flush cycle stops at the first failure rather than
// retry-storming the radio. The queue item id doubles as the Firestore
// document id (see FirestoreClient), so a retried commit upserts the same
// document -- safe to leave an item in the queue across process restarts.
// No UI imports: this module must stay safe to pull into the (:background)
// build, where the background sync service flushes directly.
(:background)
module SyncQueue {

    const MAX_QUEUE_SIZE = 100;

    // In-memory only: scoped to a single flush cycle within one process
    // (foreground app or one background wake). If the process dies
    // mid-cycle the item simply stays queued and the next trigger retries
    // it from scratch -- no state to reconcile. pendingId != null is also
    // the "a flush is in flight" guard, so there is no separate boolean for
    // that -- the two never need to disagree.
    (:background)
    var pendingId as String? = null;
    (:background)
    var pendingRetried as Boolean = false;
    (:background)
    var idCounter as Number = 0;

    // Foreground-only warning: enqueue() is only ever called from a button
    // press in the running app, never from the background process, so this
    // never needs to cross the Storage boundary the way the paused/error
    // flags in Store.queueStatus do.
    (:background)
    var queueOverflowed as Boolean = false;

    (:background)
    var onChanged as Method? = null;

    (:background)
    function setOnChanged(callback as Method?) as Void {
        onChanged = callback;
    }

    // Optional pre-dispatch check consulted at the top of flush(), before a
    // new item's commit is started -- not just before flush() is called.
    // Needed because TokenClient.getIdToken() calls its callback
    // synchronously on a cache hit (the common case for a multi-item
    // background drain, since one ID token covers an hour), so flush() ->
    // onToken() -> FirestoreClient.commitEvent() can dispatch a brand-new
    // network request in the same call stack as the previous item's
    // completion, before any caller gets a chance to check a clock. Null
    // (the foreground default) always allows dispatch. The background
    // service uses this to stop starting new items once its wall-clock
    // budget is gone, rather than aborting one already in flight.
    (:background)
    var flushGate as Method? = null;

    (:background)
    function setFlushGate(gate as Method?) as Void {
        flushGate = gate;
    }

    (:background)
    function notifyChanged() as Void {
        if (onChanged != null) {
            onChanged.invoke();
        }
    }

    (:background)
    function pendingCount() as Number {
        return Store.getSyncQueue().size();
    }

    (:background)
    function isQueueOverflowed() as Boolean {
        return queueOverflowed;
    }

    // Whether a commit is currently in flight (pendingId != null). Exposed
    // so a caller driving its own lifecycle around the flush chain (the
    // background service, deciding when it's safe to call Background.exit())
    // can tell "stopped because nothing more will happen without another
    // trigger" apart from "still working, wait for the next onChanged".
    // Accurate only because notifyChanged() below always fires after
    // pendingId has settled to its next value -- see enqueue()/advance().
    (:background)
    function isFlushing() as Boolean {
        return pendingId != null;
    }

    // Persisted (not in-memory): the background process can be the one that
    // discovers a dead refresh token, and the foreground UI needs to see
    // that after this process has already exited.
    (:background)
    function needsToken() as Boolean {
        return Store.getQueueNeedsToken();
    }

    // "shown once" -- reading it clears it.
    (:background)
    function consumeLastError() as Boolean {
        var value = Store.getQueueLastError();
        if (value) {
            Store.setQueueLastError(false);
        }
        return value;
    }

    // Returns the assigned queue id (also the Firestore document id -- see
    // FirestoreClient) so callers that need to track this specific item
    // (RecordController's SuccessView "Synced"/"Queued" status) can find it
    // again later. Keeps a caller-supplied "startMillis" if the event
    // already carries one, rather than re-deriving its own "now" -- so a
    // caller that also needs that same instant for something else (e.g.
    // Store.lastEventMillis) is guaranteed to agree with what gets queued.
    (:background)
    function enqueue(event as Dictionary) as String {
        var queue = Store.getSyncQueue();

        var id = nextId();
        event.put("id", id);
        if (event.get("startMillis") == null) {
            event.put("startMillis", TimeUtil.nowEpochMillis());
        }
        event.put("attempts", 0);
        queue.add(event);

        if (queue.size() > MAX_QUEUE_SIZE) {
            queue = queue.slice(1, null);
            queueOverflowed = true;
        }

        Store.setSyncQueue(queue);
        Store.setSyncDiagnostic("queued", 0);
        notifyChanged();
        return id;
    }

    (:background)
    function flush() as Void {
        if (pendingId != null || Store.getQueueNeedsToken()) {
            return;
        }
        var queue = Store.getSyncQueue();
        if (queue.size() == 0) {
            return;
        }
        if (flushGate != null && !(flushGate.invoke() as Boolean)) {
            return;
        }

        pendingId = queue[0].get("id") as String;
        pendingRetried = false;
        requestToken();
    }

    (:background)
    function requestToken() as Void {
        Store.setSyncDiagnostic("auth", 0);
        TokenClient.getIdToken(new Lang.Method(SyncQueue, :onToken));
    }

    (:background)
    function onToken(idToken as String?, error as Number?) as Void {
        if (idToken == null) {
            if (error == TokenClient.AUTH_INVALID) {
                pauseForToken();
            } else {
                // Network/5xx fetching the token itself -- treat like a
                // retryable commit failure.
                retryLater();
            }
            return;
        }

        var item = findItemById(pendingId);
        if (item == null) {
            // The background process already drained this item from the
            // shared queue -- move on to whatever is now at the head.
            pendingId = null;
            flush();
            return;
        }

        Store.setSyncDiagnostic("uploading", 0);
        FirestoreClient.commitEvent(item, idToken, new Lang.Method(SyncQueue, :onCommitResult));
    }

    (:background)
    function onCommitResult(status as Number, responseCode as Number) as Void {
        if (status == FirestoreClient.OK) {
            var item = removeItemById(pendingId);
            if (item != null) {
                Store.setLastEventMillis(actionForEvent(item), item.get("startMillis") as Numeric);
            }
            Store.setLastSyncMillis(TimeUtil.nowEpochMillis());
            Store.setQueueLastError(false);
            Store.setSyncDiagnostic("synced", responseCode);
            advance();
            return;
        }

        if (status == FirestoreClient.UNAUTHENTICATED) {
            Store.setSyncDiagnostic("unauthorized", responseCode);
            if (!pendingRetried) {
                pendingRetried = true;
                TokenClient.invalidateIdToken();
                requestToken();
                return;
            }
            // Already used the one retry and still unauthenticated -- stop
            // looping and surface the same paused state a refresh failure
            // would.
            pauseForToken();
            return;
        }

        if (status == FirestoreClient.PERMANENT) {
            // Never claim a rejected event synced or discard it. Keep it at
            // the head of the queue for diagnosis/manual retry.
            Store.setQueueLastError(true);
            Store.setSyncDiagnostic("rejected", responseCode);
            pendingId = null;
            pendingRetried = false;
            notifyChanged();
            return;
        }

        // RETRYABLE -- keep the item, bump its attempt count, stop flushing
        // entirely (no retry storms on-watch); the next trigger (enqueue,
        // app start, background wake) tries again.
        Store.setSyncDiagnostic("transport_error", responseCode);
        retryLater();
    }

    (:background)
    function pauseForToken() as Void {
        Store.setQueueNeedsToken(true);
        Store.setSyncDiagnostic("auth_required", 0);
        pendingId = null;
        pendingRetried = false;
        notifyChanged();
    }

    // Keeps the current head item queued for a later trigger to retry, and
    // ends this flush cycle.
    (:background)
    function retryLater() as Void {
        incrementAttemptsById(pendingId);
        pendingId = null;
        pendingRetried = false;
        notifyChanged();
    }

    // Ends this flush cycle after an item was removed (committed or
    // permanently dropped) and immediately tries the next one. flush()
    // before notifyChanged() so isFlushing() reflects whether that next
    // item actually started, not the momentary null between items.
    (:background)
    function advance() as Void {
        pendingId = null;
        pendingRetried = false;
        flush();
        notifyChanged();
    }

    (:background)
    function actionForEvent(event as Dictionary) as String {
        if ((event.get("type") as String).equals("bottle")) {
            return Store.ACTION_BOTTLE;
        }
        return (event.get("poo") == true) ? Store.ACTION_DIRTY : Store.ACTION_WET;
    }

    // Index of the queue item with the given id, or -1 -- shared by every
    // by-id queue operation below so the linear scan/compare lives in one
    // place.
    (:background)
    function indexOfId(queue as Array, id as String?) as Number {
        for (var i = 0; i < queue.size(); i++) {
            if (queue[i].get("id").equals(id)) {
                return i;
            }
        }
        return -1;
    }

    (:background)
    function findItemById(id as String?) as Dictionary? {
        var queue = Store.getSyncQueue();
        var i = indexOfId(queue, id);
        return (i >= 0) ? queue[i] : null;
    }

    (:background)
    function removeItemById(id as String?) as Dictionary? {
        var queue = Store.getSyncQueue();
        var i = indexOfId(queue, id);
        if (i < 0) {
            return null;
        }
        var removed = queue[i];
        Store.setSyncQueue(queue.slice(0, i).addAll(queue.slice(i + 1, null)));
        return removed;
    }

    function acknowledgeBrowserSync(ids as String) as Void {
        var remaining = ids;
        while (remaining.length() > 0) {
            var comma = remaining.find(",");
            var end = (comma == null) ? remaining.length() : comma;
            removeItemById(remaining.substring(0, end));
            if (comma == null) { break; }
            remaining = remaining.substring(comma + 1, remaining.length());
        }
        Store.setQueueLastError(false);
        Store.setQueueNeedsToken(false);
        Store.setLastSyncMillis(TimeUtil.nowEpochMillis());
        Store.setSyncDiagnostic("synced", 200);
        notifyChanged();
    }

    (:background)
    function incrementAttemptsById(id as String?) as Void {
        var queue = Store.getSyncQueue();
        var i = indexOfId(queue, id);
        if (i >= 0) {
            var attempts = queue[i].get("attempts");
            queue[i].put("attempts", ((attempts instanceof Number) ? attempts : 0) + 1);
            Store.setSyncQueue(queue);
        }
    }

    (:background)
    function nextId() as String {
        var id = TimeUtil.nowEpochMillis().toString() + "-" + idCounter.toString();
        idCounter += 1;
        return id;
    }

}
