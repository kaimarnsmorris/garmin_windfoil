using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Application;

// History view to display past sessions
class HistoryView extends WatchUi.View {
    private var mHistory;
    
    function initialize() {
        View.initialize();
        
        // Load session history from storage
        var storage = Application.Storage;
        mHistory = storage.getValue("sessionHistory");
        if (mHistory == null) {
            mHistory = [];
        }
    }
    
    function onLayout(dc) {
        // Layout resources
    }
    
    // Updated HistoryView code to handle Time.Moment stored as Long

    // Update in HistoryView.mc
    function onUpdate(dc) {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Draw title
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, 5, Graphics.FONT_MEDIUM, "SESSION HISTORY", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw horizontal divider
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(10, 30, width-10, 30);
        
        // Check if history exists
        if (mHistory.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, height/2, Graphics.FONT_MEDIUM, "No History", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        
        // Display the most recent 5 sessions (or fewer if less exist)
        var displayCount = (mHistory.size() < 5) ? mHistory.size() : 5;
        var yPos = 50;
        
        for (var i = 0; i < displayCount; i++) {
            var session = mHistory[mHistory.size() - 1 - i]; // Start with most recent
            
            // Format date - handle both Time.Moment and long integer for compatibility
            var dateObj;
            if (session.hasKey("date")) {
                if (session["date"] instanceof Time.Moment) {
                    dateObj = session["date"];
                } else {
                    // Convert long value back to Time.Moment
                    try {
                        dateObj = new Time.Moment(session["date"]);
                    } catch (e) {
                        // Fallback to current time if conversion fails
                        dateObj = Time.now();
                        System.println("Date conversion failed: " + e.getErrorMessage());
                    }
                }
            } else {
                dateObj = Time.now();
            }
            
            var date = Time.Gregorian.info(dateObj, Time.FORMAT_SHORT);
            var dateStr = date.month + "/" + date.day;
            
            // Draw date
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(20, yPos, Graphics.FONT_SMALL, dateStr, Graphics.TEXT_JUSTIFY_LEFT);
            
            // Draw max speed (with null safety)
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var maxSpeed = (session.hasKey("maxSpeed") && session["maxSpeed"] != null) ? 
                            session["maxSpeed"].format("%.1f") + " kt" : "0.0 kt";
            dc.drawText(width/2, yPos, Graphics.FONT_SMALL, maxSpeed, Graphics.TEXT_JUSTIFY_CENTER);
            
            // Draw % on foil (with null safety)
            var percentOnFoil = (session.hasKey("percentOnFoil") && session["percentOnFoil"] != null) ?
                                session["percentOnFoil"].format("%.0f") + "%" : "0%";
            dc.drawText(width - 20, yPos, Graphics.FONT_SMALL, percentOnFoil, Graphics.TEXT_JUSTIFY_RIGHT);
            
            // Make wind strength more prominent - UPDATED
            if (session.hasKey("windStrength") && session["windStrength"] != null) {
                // Draw a thin horizontal line to separate wind data
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(30, yPos + 17, width - 30, yPos + 17);
                
                // Draw wind strength more prominently
                dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(width/2, yPos + 25, Graphics.FONT_SMALL, "Wind: " + session["windStrength"], Graphics.TEXT_JUSTIFY_CENTER);
            }
            
            // Increase spacing between entries
            yPos += 55; // Increased from 45 to accommodate wind strength display
            
            // Add a divider except after the last item
            if (i < displayCount - 1) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(20, yPos - 10, width - 20, yPos - 10);
            }
        }
        
        // Draw navigation hint at bottom
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height - 25, Graphics.FONT_TINY, "Press BACK to return", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// History view delegate
class HistoryDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }
    
    function onBack() {
        // Pop this view when back is pressed
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}