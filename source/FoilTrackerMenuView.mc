using Toybox.WatchUi;
using Toybox.System;

// Menu view
class FoilTrackerMenuView extends WatchUi.Menu {
    function initialize() {
        Menu.initialize();
        setTitle("Foil Tracker Menu");
        
        // Add menu items
        addItem("Reset Stats", :menuItemReset);
        addItem("History", :menuItemHistory);
        addItem("Settings", :menuItemSettings);
        addItem("About", :menuItemAbout);
    }
}