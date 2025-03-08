// WindAnglePickerView.mc - final adjustments with corrected arrow

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Math;

// Wind Angle Picker View
class WindAnglePickerView extends WatchUi.View {
    private var mModel;
    public var mWindAngle;
    
    function initialize(model) {
        View.initialize();
        mModel = model;
        mWindAngle = 0; // Start at North (0 degrees)
    }
    
    function onUpdate(dc) {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Draw title - smaller font
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, 5, Graphics.FONT_TINY, "Wind Angle", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw horizontal divider
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(10, 25, width-10, 25);
        
        // Draw compass rose - outer circle, moved down
        var fontHeight = dc.getFontHeight(Graphics.FONT_SMALL) * 2/3;
        var centerX = width/2;
        var centerY = height/2 + fontHeight;
        
        // Calculate radius (using manual min function since Math.min isn't available)
        var radius;
        if (width < height) {
            radius = width / 3;
        } else {
            radius = height / 3;
        }
        
        // Draw compass circle
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, radius);
        
        // Draw cardinal points with custom offsets - all moved up by 5px
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        // North - moved up by 5px
        var northRadians = Math.toRadians(0);
        var northX = centerX + (radius + 15) * Math.sin(northRadians);
        var northY = centerY - (radius + 15) * Math.cos(northRadians) - 14;
        dc.drawText(northX, northY, Graphics.FONT_SMALL, "N", Graphics.TEXT_JUSTIFY_CENTER);
        
        // East
        var eastRadians = Math.toRadians(90);
        var eastX = centerX + (radius + 15) * Math.sin(eastRadians);
        var eastY = centerY - (radius + 15) * Math.cos(eastRadians) - 8;
        dc.drawText(eastX, eastY, Graphics.FONT_SMALL, "E", Graphics.TEXT_JUSTIFY_CENTER);
        
        // South - moved up by 15px total
        var southRadians = Math.toRadians(180);
        var southX = centerX + (radius + 15) * Math.sin(southRadians);
        var southY = centerY - (radius + 15) * Math.cos(southRadians) - 17;
        dc.drawText(southX, southY, Graphics.FONT_SMALL, "S", Graphics.TEXT_JUSTIFY_CENTER);
        
        // West - adjusted position
        var westRadians = Math.toRadians(270);
        var westX = centerX + (radius + 15) * Math.sin(westRadians);
        var westY = centerY - (radius + 15) * Math.cos(westRadians) - 13;
        dc.drawText(westX, westY, Graphics.FONT_TINY, "W", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw wind direction arrow - fixed to go FROM center TO arrowhead
        drawWindArrow(dc, centerX, centerY, radius, mWindAngle);
        
        // Get the direction name
        var directionName = getDirectionName(mWindAngle);
        
        // Draw the selected angle text - using extra small font for all angles
        // Move angle display up by 5px (total 20px up from original)
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, centerY + (radius * 0.67) - 20, Graphics.FONT_TINY, mWindAngle.format("%d") + "°", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw direction name
        dc.drawText(centerX, centerY + (radius * 0.67) + 5, Graphics.FONT_TINY, directionName, Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    // Helper to draw the wind direction arrow - FIXED TO GO FROM CENTER TO ARROWHEAD
    function drawWindArrow(dc, centerX, centerY, arrowLength, angle) {
        // Convert angle to radians
        var radians = Math.toRadians(angle);
        
        // FIXED: Arrow FROM center TO arrowhead position (40% of radius)
        // Start from center
        var startX = centerX;
        var startY = centerY;
        
        // End at arrowhead position (40% of radius)
        var endRadius = arrowLength * 0.4;
        var endX = centerX + endRadius * Math.sin(radians);
        var endY = centerY - endRadius * Math.cos(radians);
        
        // Draw the arrow shaft - dark green color
        dc.setColor(0x006400, Graphics.COLOR_TRANSPARENT); // Dark green
        dc.setPenWidth(3);
        dc.drawLine(startX, startY, endX, endY);
        dc.setPenWidth(1);
        
        // Draw arrow head at end
        var headSize = 10;
        var headAngle1 = Math.toRadians(angle + 150); // Arrow pointing outward
        var headAngle2 = Math.toRadians(angle - 150); // Arrow pointing outward
        
        var head1X = endX + headSize * Math.sin(headAngle1);
        var head1Y = endY - headSize * Math.cos(headAngle1);
        var head2X = endX + headSize * Math.sin(headAngle2);
        var head2Y = endY - headSize * Math.cos(headAngle2);
        
        dc.drawLine(endX, endY, head1X, head1Y);
        dc.drawLine(endX, endY, head2X, head2Y);
    }
    
    // Helper to get the directional name based on angle
    function getDirectionName(angle) {
        var directions = [
            "N", "NNE", "NE", "ENE", 
            "E", "ESE", "SE", "SSE", 
            "S", "SSW", "SW", "WSW", 
            "W", "WNW", "NW", "NNW"
        ];
        
        // Calculate the index in the directions array
        // Each direction covers 22.5 degrees (360/16)
        var index = (angle / 22.5).toNumber() % 16;
        return directions[index];
    }
}

// Wind Angle Picker Delegate - Updated to properly set wind direction in WindTracker
class WindAnglePickerDelegate extends WatchUi.BehaviorDelegate {
    private var mModel;
    private var mPickerView;
    private var mApp;
    
    function initialize(model, app) {
        BehaviorDelegate.initialize();
        mModel = model;
        mPickerView = null;
        mApp = app;
    }
    
    function setPickerView(view) {
        mPickerView = view;
    }
    
    // Handle up button - decrease angle
    function onPreviousPage() {
        if (mPickerView != null) {
            // Decrement by 22.5 degrees, keeping in 0-359.9 range
            var newAngle = mPickerView.mWindAngle - 22.5;
            if (newAngle < 0) {
                newAngle += 360;
            }
            mPickerView.mWindAngle = newAngle;
            WatchUi.requestUpdate();
        }
        return true;
    }
    
    // Handle down button - increase angle
    function onNextPage() {
        if (mPickerView != null) {
            // Increment by 22.5 degrees, keeping in 0-359.9 range
            var newAngle = mPickerView.mWindAngle + 22.5;
            if (newAngle >= 360) {
                newAngle -= 360;
            }
            mPickerView.mWindAngle = newAngle;
            WatchUi.requestUpdate();
        }
        return true;
    }
    
    // Handle select button - confirm selection and proceed
    function onSelect() {
        try {
            // Get selected wind angle from the view
            if (mPickerView != null) {
                var windAngle = mPickerView.mWindAngle;
                
                // Store the selected wind angle in the model
                if (mModel != null) {
                    // Add wind angle to the model data
                    mModel.getData()["initialWindAngle"] = windAngle;
                    System.println("Selected wind angle: " + windAngle);
                    
                    // Save this as the manual wind direction
                    mModel.getData()["manualWindDirection"] = windAngle;
                }
                
                // Set the wind direction in the WindTracker
                var windTracker = mApp.getWindTracker();
                if (windTracker != null) {
                    windTracker.setInitialWindDirection(windAngle);
                }
                
                // Now start the activity session with the wind data
                if (mApp != null) {
                    // Start the activity recording session
                    mApp.startActivitySession();
                    
                    // Switch to the main app view
                    var view = new FoilTrackerView(mModel);
                    var delegate = new FoilTrackerDelegate(view, mModel, mApp.getWindTracker());
                    WatchUi.switchToView(view, delegate, WatchUi.SLIDE_IMMEDIATE);
                }
            }
        } catch (e) {
            System.println("Error in wind angle selection: " + e.getErrorMessage());
            
            // Fall back to main view if there's an error
            var view = new FoilTrackerView(mModel);
            var delegate = new FoilTrackerDelegate(view, mModel, mApp.getWindTracker());
            WatchUi.switchToView(view, delegate, WatchUi.SLIDE_IMMEDIATE);
        }
        
        return true;
    }
    
    // Handle back button - go back to wind strength picker
    function onBack() {
        // Go back to wind strength picker
        var app = Application.getApp();
        var windView = new WindStrengthPickerView(mModel);
        var windDelegate = new StartupWindStrengthDelegate(mModel, app);
        windDelegate.setPickerView(windView);
        
        WatchUi.switchToView(windView, windDelegate, WatchUi.SLIDE_DOWN);
        return true;
    }
}