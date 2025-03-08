using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Math;

// VMG View class for wind angle and VMG calculations
class VMGView extends WatchUi.View {
    private var mModel;
    private var mWindTracker;
    private var mWindDirection;
    private var mVmg;
    private var mIsUpwind;
    private var mCurrentTack;
    private var mLastTackAngle;
    private var mLastGybeAngle;
    private var mTackCount;
    private var mGybeCount;
    private var mWindMode;
    private var mLastRefreshTime;
    private var mForcedUpdate;
    private var mWindAngle;
    private var mDataChanged;
    private var mTackDisplayText;
    private var mTackColorId;
    
    // Constructor
    function initialize(model, windTracker) {
        View.initialize();
        mModel = model;
        mWindTracker = windTracker;
        
        // Initialize with default values
        mWindDirection = 0;
        mVmg = 0.0;
        mIsUpwind = true;
        mCurrentTack = "Unknown";
        mLastTackAngle = 0;
        mLastGybeAngle = 0;
        mTackCount = 0;
        mGybeCount = 0;
        mWindMode = "Manual";
        mLastRefreshTime = 0;
        mForcedUpdate = true;
        mWindAngle = 0;
        mDataChanged = false;
        mTackDisplayText = "Stb";
        mTackColorId = 1; // 1 = green, 2 = red
        
        // Get initial values from wind tracker
        updateFromWindTracker();
    }
    
    // Force a refresh of the view
    function forceRefresh() {
        mForcedUpdate = true;
        WatchUi.requestUpdate();
    }
    
    // Update data from wind tracker
    function updateFromWindTracker() {
        var windData = mWindTracker.getWindData();
        mDataChanged = false;
        
        if (windData != null && windData.hasKey("valid") && windData["valid"]) {
            // Check wind direction
            if (windData.hasKey("windDirection") && mWindDirection != windData["windDirection"]) { 
                mWindDirection = windData["windDirection"];
                mDataChanged = true;
            }
            
            // Check VMG
            if (windData.hasKey("currentVMG") && mVmg != windData["currentVMG"]) { 
                mVmg = windData["currentVMG"]; 
                mDataChanged = true;
            }
            
            // Check point of sail
            if (windData.hasKey("currentPointOfSail")) {
                var newUpwind = (windData["currentPointOfSail"] == "Upwind");
                
                if (mIsUpwind != newUpwind) {
                    mIsUpwind = newUpwind;
                    mDataChanged = true;
                }
            }
            
            // Check current tack
            if (windData.hasKey("currentTack")) {
                var newTack = windData["currentTack"];
                if (mCurrentTack != newTack) {
                    mCurrentTack = newTack;
                    mDataChanged = true;
                    WatchUi.requestUpdate();
                }
            }
            
            // Check wind angle
            if (windData.hasKey("windAngleLessCOG")) {
                var newAngle = windData["windAngleLessCOG"];
                if (newAngle != mWindAngle) {
                    mWindAngle = newAngle;
                    mDataChanged = true;
                }
            }
            
            // Check tack angle
            if (windData.hasKey("lastTackAngle") && mLastTackAngle != windData["lastTackAngle"]) { 
                mLastTackAngle = windData["lastTackAngle"]; 
                mDataChanged = true;
            }
            
            // Check gybe angle
            if (windData.hasKey("lastGybeAngle") && mLastGybeAngle != windData["lastGybeAngle"]) { 
                mLastGybeAngle = windData["lastGybeAngle"]; 
                mDataChanged = true;
            }
            
            // Check tack count
            if (windData.hasKey("tackCount") && mTackCount != windData["tackCount"]) { 
                mTackCount = windData["tackCount"]; 
                mDataChanged = true;
            }
            
            // Check gybe count
            if (windData.hasKey("gybeCount") && mGybeCount != windData["gybeCount"]) { 
                mGybeCount = windData["gybeCount"]; 
                mDataChanged = true;
            }
            
            // Check tack display text
            if (windData.hasKey("tackDisplayText")) {
                mTackDisplayText = windData["tackDisplayText"];
            }
            
            // Check tack color ID
            if (windData.hasKey("tackColorId")) {
                mTackColorId = windData["tackColorId"];
            }
            
            // Check wind mode
            var newMode = "Manual";
            if (windData.hasKey("windDirectionLocked") && windData["windDirectionLocked"]) {
                newMode = "Locked";
            } else if (windData.hasKey("autoWindDetection") && windData["autoWindDetection"]) {
                newMode = "Auto";
            }
            
            if (mWindMode != newMode) {
                mWindMode = newMode;
                mDataChanged = true;
            }
            
            // Store the refresh time to monitor updates
            mLastRefreshTime = System.getTimer();
            
            // If data changed, explicitly request a UI update
            if (mDataChanged) {
                WatchUi.requestUpdate();
            }
        }
        
        return mDataChanged;
    }
    
    // On layout
    function onLayout(dc) {
        // Nothing special needed
    }
    
    // Update the view
    function onUpdate(dc) {
        // Always update from wind tracker
        updateFromWindTracker();
        
        // Get absolute wind angle value
        var absWindAngle = (mWindAngle < 0) ? -mWindAngle : mWindAngle;
        
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Display VMG value in larger white font
        var vmgStr = mVmg.format("%.1f");
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // Use a larger font for VMG
        dc.drawText(width/2, 10, Graphics.FONT_NUMBER_THAI_HOT, vmgStr, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Set color based on tack color ID from model
        var textColor = (mTackColorId == 1) ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        
        // Draw tack indicator text to the left of the wind angle with correct color
        // Moved down 20px as requested (from y=85 to y=105)
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(90, 105, Graphics.FONT_SMALL, mTackDisplayText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(130, 90, Graphics.FONT_NUMBER_MEDIUM, absWindAngle.format("%d") + "°", Graphics.TEXT_JUSTIFY_LEFT);
        
        // Statistics section - Tacks/Gybes moved right 10px
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        
        // Tacks section
        dc.drawText(25, 140, Graphics.FONT_TINY, "Tacks: " + mTackCount, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Last tack angle directly underneath
        var tackText = "Last: ";
        if (mTackCount > 0) {
            tackText += mLastTackAngle.format("%d") + "°";
        } else {
            tackText += "--";
        }
        dc.drawText(25, 160, Graphics.FONT_TINY, tackText, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Gybes section
        dc.drawText(140, 140, Graphics.FONT_TINY, "Gybes: " + mGybeCount, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Last gybe angle directly underneath
        var gybeText = "Last: ";
        if (mGybeCount > 0) {
            gybeText += mLastGybeAngle.format("%d") + "°";
        } else {
            gybeText += "--";
        }
        dc.drawText(140, 160, Graphics.FONT_TINY, gybeText, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Draw wind direction and mode at bottom
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height - 40, Graphics.FONT_TINY, "Wind: " + mWindDirection.format("%d") + "°", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, height - 60, Graphics.FONT_TINY, mWindMode + " wind mode", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
