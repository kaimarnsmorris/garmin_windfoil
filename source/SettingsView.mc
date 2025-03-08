using Toybox.WatchUi;
using Toybox.Graphics;

// Settings view
class SettingsView extends WatchUi.View {
    private var mModel;
    public var mSelectedOption;
    
    function initialize(model) {
        View.initialize();
        mModel = model;
        mSelectedOption = 0; // 0: Threshold, 1: Background, 2: Reset All
    }
    
    function onLayout(dc) {
        // Layout resources
    }
    
    function onUpdate(dc) {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Draw title
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, 5, Graphics.FONT_MEDIUM, "SETTINGS", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw horizontal divider
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(10, 30, width-10, 30);
        
        // Settings options
        var settings = mModel.getData()["settings"];
        
        // Option 1: Foiling Threshold
        if (mSelectedOption == 0) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(width/2, 50, Graphics.FONT_SMALL, "Foiling Threshold", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, 75, Graphics.FONT_MEDIUM, settings["foilingThreshold"].format("%.1f") + " kt", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw controls hint
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height - 50, Graphics.FONT_TINY, "UP/DOWN: Select, SELECT: Change", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, height - 25, Graphics.FONT_TINY, "BACK: Return", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// Settings delegate
class SettingsDelegate extends WatchUi.BehaviorDelegate {
    private var mModel;
    private var mSettingsView;
    
    function initialize(model) {
        BehaviorDelegate.initialize();
        mModel = model;
        mSettingsView = null;
    }
    
    // Store a reference to the view
    function setSettingsView(view) {
        mSettingsView = view;
    }
    
    function onNextPage() {
        // Use the stored view reference instead of getCurrentView
        if (mSettingsView != null) {
            mSettingsView.mSelectedOption = (mSettingsView.mSelectedOption + 1) % 3;
            WatchUi.requestUpdate();
        }
        return true;
    }
    
    function onPreviousPage() {
        if (mSettingsView != null) {
            mSettingsView.mSelectedOption = (mSettingsView.mSelectedOption + 2) % 3;
            WatchUi.requestUpdate();
        }
        return true;
    }
    
    function onSelect() {
        if (mSettingsView != null) {
            var settings = mModel.getData()["settings"];
            if (mSettingsView.mSelectedOption == 0) {
                settings["foilingThreshold"] += 0.5;
                if (settings["foilingThreshold"] > 12.0) {
                    settings["foilingThreshold"] = 5.0;
                }
            }
            mModel.saveSettings();
            WatchUi.requestUpdate();
        }
        return true;
    }
    
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}