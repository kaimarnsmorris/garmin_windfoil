using Toybox.WatchUi;
using Toybox.System;

// Menu input handler
class FoilTrackerMenuDelegate extends WatchUi.MenuInputDelegate {
    private var mModel;
    
    function initialize(model) {
        MenuInputDelegate.initialize();
        mModel = model;
    }
    
    // Handle menu selection
    function onMenuItem(item) {
        if (item == :menuItemReset) {
            // Reset current stats
            var data = mModel.getData();
            data["maxSpeed"] = 0.0;
            data["max3sSpeed"] = 0.0;
            data["timeAboveThreshold"] = 0;
            data["percentOnFoil"] = 0.0;
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (item == :menuItemHistory) {
            // Show history screen
            WatchUi.pushView(new HistoryView(), new HistoryDelegate(), WatchUi.SLIDE_LEFT);
        } else if (item == :menuItemSettings) {
            // Show settings screen with proper view/delegate connection
            var view = new SettingsView(mModel);
            var delegate = new SettingsDelegate(mModel);
            delegate.setSettingsView(view);
            WatchUi.pushView(view, delegate, WatchUi.SLIDE_UP);
        } else if (item == :menuItemAbout) {
            // Show About screen
            WatchUi.pushView(new AboutView(), new AboutDelegate(), WatchUi.SLIDE_UP);
        }
    }
}