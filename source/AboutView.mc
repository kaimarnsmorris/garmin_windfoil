using Toybox.WatchUi;
using Toybox.Graphics;

// About view
class AboutView extends WatchUi.View {
    function initialize() {
        View.initialize();
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
        
        // Draw about text
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height/4 - 20, Graphics.FONT_MEDIUM, "FOIL TRACKER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, height/4 + 15, Graphics.FONT_SMALL, "Version 1.0", Graphics.TEXT_JUSTIFY_CENTER);
        
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height/2, Graphics.FONT_TINY, "Tracks:", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, height/2 + 20, Graphics.FONT_TINY, "1. Max Speed", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, height/2 + 40, Graphics.FONT_TINY, "2. Max 3s Speed", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, height/2 + 60, Graphics.FONT_TINY, "3. Time on Foil %", Graphics.TEXT_JUSTIFY_CENTER);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, 3*height/4 + 20, Graphics.FONT_TINY, "© 2025", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// About view delegate
class AboutDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
    
    function onBack() {
        // Pop this view when back is pressed
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}