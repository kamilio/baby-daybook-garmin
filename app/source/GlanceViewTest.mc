import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

module GlanceViewTest {
    const DAY = 86400000L;

    (:test)
    function testMissingAndFutureBirthday(logger as Test.Logger) as Boolean {
        var view = new GlanceView();
        return view.ageLabel(10L * DAY, null).equals("")
            && view.ageLabel(10L * DAY, 11L * DAY).equals("Newborn");
    }

    (:test)
    function testNewbornAndDayCases(logger as Test.Logger) as Boolean {
        var view = new GlanceView();
        var birthday = 100L * DAY;
        return view.ageLabel(birthday, birthday).equals("Newborn")
            && view.ageLabel(birthday + DAY, birthday).equals("1 day")
            && view.ageLabel(birthday + 6L * DAY, birthday).equals("6 days");
    }

    (:test)
    function testWeekAndRemainingDayCases(logger as Test.Logger) as Boolean {
        var view = new GlanceView();
        return view.ageLabel(7L * DAY, 0L).equals("1 w")
            && view.ageLabel(8L * DAY, 0L).equals("1 w 1 day")
            && view.ageLabel(10L * DAY, 0L).equals("1 w 3 days")
            && view.ageLabel(83L * DAY, 0L).equals("11 w 6 days");
    }

    (:test)
    function testMonthCasesAndBoundaries(logger as Test.Logger) as Boolean {
        var view = new GlanceView();
        return view.ageLabel(84L * DAY, 0L).equals("2 months")
            && view.ageLabel(365L * DAY, 0L).equals("12 months")
            && view.ageLabel(729L * DAY, 0L).equals("23 months");
    }

    (:test)
    function testYearAndRemainingMonthCases(logger as Test.Logger) as Boolean {
        var view = new GlanceView();
        return view.ageLabel(730L * DAY, 0L).equals("2 years")
            && view.ageLabel((2L * 365L + 92L) * DAY, 0L).equals("2 years 3 mo")
            && view.ageLabel(3L * 365L * DAY, 0L).equals("3 years");
    }

    (:test)
    function testBabyProfileRoundTripsForGlance(logger as Test.Logger) as Boolean {
        Storage.clearValues();
        Store.setBabyProfile("Victoria", 1234L);
        var profile = Store.getBabyProfile();
        var ok = profile.get("name").equals("Victoria") && profile.get("birthdayMillis") == 1234L;
        Storage.clearValues();
        return ok;
    }
}
