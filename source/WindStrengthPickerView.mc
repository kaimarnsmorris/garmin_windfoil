// Updated WindStrengthPickerView with Title Case Header

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;

// Wind Strength Picker View
class WindStrengthPickerView extends WatchUi.View {
    private var mModel;
    public var mSelectedIndex;
    
    function initialize(model) {
        View.initialize();
        mModel = model;
        mSelectedIndex = 0;
    }
    
    function onUpdate(dc) {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Draw title - changed from ALL CAPS to Title Case and moved down
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var fontHeight = dc.getFontHeight(Graphics.FONT_SMALL) / 2;
        dc.drawText(width/2, 5 + fontHeight, Graphics.FONT_SMALL, "Wind Strength", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw horizontal divider
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(10, 30 + fontHeight, width-10, 30 + fontHeight);
        
        // Get wind strength options
        var options = mModel.getWindStrengthOptions();
        
        // Draw the selected option with highlight color
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height/2, Graphics.FONT_MEDIUM, options[mSelectedIndex], Graphics.TEXT_JUSTIFY_CENTER);
        
        // Get font height to better position arrows
        var mediumFontHeight = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var arrowOffset = mediumFontHeight / 2;  // Half the font height
        
        // Draw prev/next indicators
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        
        // Draw up arrow for previous - moved based on font height
        if (mSelectedIndex > 0) {
            // Simple triangle for up arrow
            dc.drawLine(width/2, height/2 - 40 - arrowOffset, width/2 - 10, height/2 - 30 - arrowOffset);
            dc.drawLine(width/2, height/2 - 40 - arrowOffset, width/2 + 10, height/2 - 30 - arrowOffset);
            dc.drawLine(width/2 - 10, height/2 - 30 - arrowOffset, width/2 + 10, height/2 - 30 - arrowOffset);
        }
        
        // Draw down arrow for next - moved based on font height
        if (mSelectedIndex < options.size() - 1) {
            // Simple triangle for down arrow
            dc.drawLine(width/2, height/2 + 40 + arrowOffset, width/2 - 10, height/2 + 30 + arrowOffset);
            dc.drawLine(width/2, height/2 + 40 + arrowOffset, width/2 + 10, height/2 + 30 + arrowOffset);
            dc.drawLine(width/2 - 10, height/2 + 30 + arrowOffset, width/2 + 10, height/2 + 30 + arrowOffset);
        }
        
        // Removed instruction text at bottom as requested
    }
}