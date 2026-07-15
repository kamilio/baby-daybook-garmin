import Toybox.Lang;

// Offline-first queue shared by foreground and background processes. Every
// event is persisted before RelaySync sends it through Fly. This module has
// no network client of its own, so there is only one production transport.
(:background)
module SyncQueue {
    const MAX_QUEUE_SIZE = 100;

    (:background)
    var idCounter as Number = 0;
    (:background)
    var queueOverflowed as Boolean = false;
    (:background)
    var onChanged as Method? = null;

    (:background)
    function setOnChanged(callback as Method?) as Void { onChanged = callback; }

    (:background)
    function notifyChanged() as Void {
        if (onChanged != null) { onChanged.invoke(); }
    }

    (:background)
    function pendingCount() as Number { return Store.getPendingCount(); }

    (:background)
    function isQueueOverflowed() as Boolean { return queueOverflowed; }

    (:background)
    function needsToken() as Boolean { return Store.getQueueNeedsToken(); }

    (:background)
    function consumeLastError() as Boolean {
        var value = Store.getQueueLastError();
        if (value) { Store.setQueueLastError(false); }
        return value;
    }

    (:background)
    function enqueue(event as Dictionary) as String {
        var queue = Store.getSyncQueue();
        var id = nextId();
        event.put("id", id);
        if (event.get("startMillis") == null) {
            event.put("startMillis", TimeUtil.nowEpochMillis());
        }
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
    function indexOfId(queue as Array, id as String?) as Number {
        for (var i = 0; i < queue.size(); i++) {
            if (queue[i].get("id").equals(id)) { return i; }
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
        if (i < 0) { return null; }
        var removed = queue[i];
        Store.setSyncQueue(queue.slice(0, i).addAll(queue.slice(i + 1, null)));
        return removed;
    }

    (:background)
    function acknowledgeRelaySync(ids as Array) as Void {
        for (var i = 0; i < ids.size(); i++) {
            if (ids[i] instanceof String) { removeItemById(ids[i]); }
        }
        Store.setQueueLastError(false);
        Store.setQueueNeedsToken(false);
        Store.setLastSyncMillis(TimeUtil.nowEpochMillis());
        Store.setSyncDiagnostic("relay_synced", 200);
        notifyChanged();
    }

    (:background)
    function nextId() as String {
        var id = TimeUtil.nowEpochMillis().toString() + "-" + idCounter.toString();
        idCounter += 1;
        return id;
    }
}
