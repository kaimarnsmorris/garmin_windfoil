using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;

// View class for rendering the foil tracker UI
class FoilTrackerView extends WatchUi.View {
    // Class variables
    private var mModel;
    private var mShowLapFeedback;
    private var mLapFeedbackTimer;
    
    // Constructor
    function initialize(model) {
        View.initialize();
        mModel = model;
        mShowLapFeedback = false;
        mLapFeedbackTimer = 0;
    }
    
    // Display lap feedback for a short time
    function showLapFeedback() {
        mShowLapFeedback = true;
        mLapFeedbackTimer = System.getTimer();
        WatchUi.requestUpdate();
    }
    
    // Load UI resources
    function onLayout(dc) {
        // We now use system fonts instead of custom fonts
    }
    
    // Update the view
    function onUpdate(dc) {
        var data = mModel.getData();
        
        // Clear the screen with background color
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions - important for proper scaling
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Check if lap feedback should be turned off
        if (mShowLapFeedback) {
            var currentTime = System.getTimer();
            if (currentTime - mLapFeedbackTimer > 2000) { // 2 seconds feedback
                mShowLapFeedback = false;
            }
        }
        
        // Check if session is paused
        var isPaused = data.hasKey("sessionPaused") && data["sessionPaused"];
        
        // Draw current speed with color based on foiling state
        if (isPaused) {
            // Yellow when paused
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        } else if (data["isOnFoil"]) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        
        // Format current speed - use larger area for main speed display
        var speedStr = data["currentSpeed"].format("%.1f");
        
        // Draw the current speed larger at the top
        // Removed "kts" text as requested
        dc.drawText(width/2, 10, Graphics.FONT_NUMBER_HOT, speedStr, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw max speeds section in the middle - MOVED UP 5px
        var statsY = height/3 + 5; // Changed from +15 to +5
        
        // Max speed - left side
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/4, statsY, Graphics.FONT_TINY, "Max", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/4, statsY + 20, Graphics.FONT_MEDIUM, data["maxSpeed"].format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        
        // Max 3s speed - right side
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(3*width/4, statsY, Graphics.FONT_TINY, "Max 3s", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(3*width/4, statsY + 20, Graphics.FONT_MEDIUM, data["max3sSpeed"].format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        
        // ONLY VERTICAL divider line between max speeds - horizontal line removed
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(width/2, statsY, width/2, statsY + 40);
        
        // Foiling percentage - MOVED UP further to avoid bar overlap
        var percentY = height * 2/3 - 15;
        var percentOnFoil = data["percentOnFoil"];
        var barWidth = (width - 20) * percentOnFoil / 100.0;
        
        // Draw percentage with "on foil" text beside it - moved up more
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2 - 25, percentY - 10, Graphics.FONT_MEDIUM, percentOnFoil.format("%.0f") + "%", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2 + 5, percentY - 7, Graphics.FONT_TINY, "on foil", Graphics.TEXT_JUSTIFY_LEFT);
        
        // Background bar - keep at same position
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
        dc.fillRectangle(10, percentY + 30, width - 20, 10);
        
        // Foreground progress bar
        if (percentOnFoil > 0) {
            // Color based on percentage
            if (percentOnFoil > 50) {
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
            } else if (percentOnFoil > 25) {
                dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_YELLOW);
            } else {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
            }
            dc.fillRectangle(10, percentY + 30, barWidth.toNumber(), 10);
        }
        
        // Draw elapsed time at bottom - MOVED UP to avoid being cut off
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        
        // Format elapsed time as hours:minutes:seconds
        var elapsedSecs = 0;
        if (data.hasKey("totalTime")) {
            elapsedSecs = data["totalTime"];
            
            // Subtract total pause time 
            if (data.hasKey("totalPauseTime")) {
                elapsedSecs -= data["totalPauseTime"] / 1000;
            }
            
            // If currently paused, also subtract current pause duration
            if (data.hasKey("sessionPaused") && data["sessionPaused"] && data.hasKey("pauseStartTime")) {
                var currentPauseDuration = (System.getTimer() - data["pauseStartTime"]) / 1000;
                elapsedSecs -= currentPauseDuration;
            }
            
            if (elapsedSecs < 0) {
                elapsedSecs = 0;
            }
        }
        
        // Calculate hours, minutes, seconds
        var hours = (elapsedSecs / 3600).toNumber();
        var minutes = ((elapsedSecs % 3600) / 60).toNumber();
        var seconds = (elapsedSecs % 60).toNumber();
        
        // Format with hours, minutes and seconds: h:mm:ss
        var timeStr = hours.format("%d") + ":" + minutes.format("%02d") + ":" + seconds.format("%02d");
        
        // Draw the time string - MOVED UP
        dc.drawText(width/2, height - 40, Graphics.FONT_SMALL, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw recording/paused indicator
        if (isPaused) {
            // PAUSED text for clear indication - made smaller
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, height - 60, Graphics.FONT_TINY, "PAUSED", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (data["isRecording"]) {
            // Blinking red dot for recording indication
            // Use a different variable name to avoid conflict
            var timerSeconds = System.getTimer() / 1000;
            if ((timerSeconds % 2).toNumber() == 0) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
                dc.fillCircle(width - 15, 15, 5);
            }
        }
        
        // Draw lap feedback if active
        if (mShowLapFeedback) {
            // Draw LAP MARKER notice at the top of the screen
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
            dc.fillRectangle(0, 0, width, 25);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, 2, Graphics.FONT_SMALL, "LAP MARKED", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        // Draw "Light=Lap" indicator at bottom
        if (!mShowLapFeedback && !isPaused && data["isRecording"]) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, height - 20, Graphics.FONT_TINY, "Light=Lap", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}