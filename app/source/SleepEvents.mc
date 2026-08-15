import Toybox.Lang;

module SleepEvents {
    function start(nowMillis as Numeric) as Dictionary {
        return {
            "type" => "sleeping",
            "startMillis" => nowMillis,
            "inProgress" => true,
            "watchLabel" => "Sleep started"
        };
    }

    function stop(active as Dictionary, nowMillis as Numeric) as Dictionary {
        var startMillis = active.get("startMillis") as Numeric;
        var duration = nowMillis - startMillis;
        if (duration < 0) { duration = 0; }
        return {
            "type" => "sleeping",
            "activityId" => active.get("activityId"),
            "startMillis" => startMillis,
            "endMillis" => nowMillis,
            "duration" => duration,
            "inProgress" => false,
            "watchLabel" => "Sleep stopped"
        };
    }
}
