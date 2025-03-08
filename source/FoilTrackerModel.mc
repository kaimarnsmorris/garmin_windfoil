// Modified sections of FoilTrackerModel.mc for data point counting approach

using Toybox.System;
using Toybox.Application;
using Toybox.Time;
using Toybox.Graphics;

class FoilTrackerModel {
    // Constants
    private const KNOTS_CONVERSION = 1.943844; // m/s to knots
    private const FOILING_THRESHOLD = 7.0;     // Speed threshold for foiling (knots)
    private const BUFFER_SIZE = 10;            // Size of rolling buffer for 3s max speed
    private const SIGNIFICANT_CHANGE = 0.5;    // Speed change threshold to trigger UI update
    
    // Updated wind ranges with 3-knot increments
    private const WIND_STRENGTHS = [
        "7-10 knots",
        "10-13 knots",
        "13-16 knots",
        "16-19 knots",
        "19-22 knots",
        "22-25 knots",
        "25+ knots"
    ];
    
    // Application data
    private var mData;
    private var mSettings;
    private var mSpeedBuffer;
    private var mBufferIndex;
    private var mLastSignificantSpeed;
    private var mActivityStartTime;
    
    // NEW: Count-based tracking for "% on foil"
    private var mTotalDataPoints;
    private var mFoilingDataPoints;
    
    private var mSessionStats;
    private var mWindStrength;
    private var mSession;
    
    // Constructor
    function initialize() {
        mData = {
            "currentSpeed" => 0.0,          // Current speed in knots
            "maxSpeed" => 0.0,              // Max speed in knots (instantaneous)
            "max3sSpeed" => 0.0,            // Max 3-second average speed in knots
            "percentOnFoil" => 0.0,         // Percentage of time on foil
            "totalTime" => 0,               // Total session time (seconds)
            "isRecording" => true,          // Recording status
            "isOnFoil" => false,            // Current foiling status
            "windStrength" => null,         // Selected wind strength
            "sessionPaused" => false,       // Pause state tracking
            "pauseStartTime" => 0,          // When pause started (in milliseconds)
            "totalPauseTime" => 0,          // Total time paused in milliseconds
            "sessionComplete" => false      // Whether session is fully complete
        };
        
        // Initialize speed buffer for 3-second max speed calculation
        mSpeedBuffer = new [BUFFER_SIZE];
        for (var i = 0; i < BUFFER_SIZE; i++) {
            mSpeedBuffer[i] = 0.0;
        }
        mBufferIndex = 0;
        mLastSignificantSpeed = 0.0;
        
        // NEW: Initialize data point counters
        mTotalDataPoints = 0;
        mFoilingDataPoints = 0;
        
        // Track time spent foiling
        mActivityStartTime = System.getTimer();  // Start time in milliseconds
        
        mWindStrength = null;
        mSession = null;
        
        // Session stats for saving
        mSessionStats = {
            "maxSpeed" => 0.0,
            "max3sSpeed" => 0.0,
            "percentOnFoil" => 0.0,
            "totalTime" => 0,
            "windStrength" => null
        };
        
        // Load settings from storage if available
        loadSettings();
    }
    
    // Add this function to properly handle pausing
    function setPauseState(isPaused) {
        if (isPaused && !mData["sessionPaused"]) {
            // Starting a pause - record the pause start time
            mData["sessionPaused"] = true;
            mData["pauseStartTime"] = System.getTimer();
            System.println("Pause started at: " + mData["pauseStartTime"]);
        } 
        else if (!isPaused && mData["sessionPaused"]) {
            // Ending a pause - calculate and add to total pause time
            mData["sessionPaused"] = false;
            var currentTime = System.getTimer();
            var pauseDuration = currentTime - mData["pauseStartTime"];
            mData["totalPauseTime"] += pauseDuration;
            System.println("Pause ended - duration: " + pauseDuration + "ms, total: " + mData["totalPauseTime"] + "ms");
        }
    }
    
    // Get current speed
    function getCurrentSpeed() {
        return mData["currentSpeed"];
    }
    
    // Process GPS location data (called whenever location updates)
    function processLocationData(info) {
        if (info has :speed && info.speed != null) {
            // Only count data points when not paused and recording
            var isActive = mData["isRecording"] && !(mData.hasKey("sessionPaused") && mData["sessionPaused"]);
            
            // Convert m/s to knots
            var speedKnots = info.speed * KNOTS_CONVERSION;
            
            // Update current speed
            mData["currentSpeed"] = speedKnots;
            
            // Update max speed if needed
            if (speedKnots > mData["maxSpeed"]) {
                mData["maxSpeed"] = speedKnots;
                mSessionStats["maxSpeed"] = speedKnots;
            }
            
            // Add to rolling buffer for 3s average calculation
            mSpeedBuffer[mBufferIndex] = speedKnots;
            mBufferIndex = (mBufferIndex + 1) % BUFFER_SIZE;
            
            // Calculate current 3s average speed (using available data points)
            var sum = 0.0;
            var count = 0;
            for (var i = 0; i < BUFFER_SIZE; i++) {
                if (mSpeedBuffer[i] > 0.0) {
                    sum += mSpeedBuffer[i];
                    count++;
                }
            }
            
            var avg3sSpeed = (count > 0) ? sum / count : 0.0;
            
            // Update max 3s speed if needed
            if (avg3sSpeed > mData["max3sSpeed"]) {
                mData["max3sSpeed"] = avg3sSpeed;
                mSessionStats["max3sSpeed"] = avg3sSpeed;
            }
            
            // Update foiling status based on instantaneous speed
            var wasOnFoil = mData["isOnFoil"];
            var isOnFoil = (speedKnots >= FOILING_THRESHOLD);
            mData["isOnFoil"] = isOnFoil;
            
            // NEW: Count data points for percentage calculation
            if (isActive) {
                mTotalDataPoints++;
                
                if (isOnFoil) {
                    mFoilingDataPoints++;
                }
                
                // Calculate percentage immediately
                if (mTotalDataPoints > 0) {
                    var percentOnFoil = (mFoilingDataPoints * 100.0) / mTotalDataPoints;
                    mData["percentOnFoil"] = percentOnFoil;
                    mSessionStats["percentOnFoil"] = percentOnFoil;
                    
                    System.println("Speed: " + speedKnots.format("%.1f") + 
                                  " - On Foil: " + isOnFoil + 
                                  " - Points: " + mFoilingDataPoints + "/" + mTotalDataPoints + 
                                  " = " + percentOnFoil.format("%.1f") + "%");
                }
            }
            
            // If we've just started foiling, print a debug message
            if (!wasOnFoil && isOnFoil) {
                System.println("Started foiling at " + speedKnots + " knots");
            }
        }
    }
    
    // Update application data (called on timer)
    function updateData() {
        // Update total session time
        var currentTime = System.getTimer();
        var elapsedMilliseconds = currentTime - mActivityStartTime;
        var elapsedSeconds = elapsedMilliseconds / 1000;
        mData["totalTime"] = elapsedSeconds;
        mSessionStats["totalTime"] = elapsedSeconds;
        
        // Update battery and time for display
        mData["battery"] = System.getSystemStats().battery;
        var now = System.getClockTime();
        mData["time"] = now.hour.format("%02d") + ":" + now.min.format("%02d");
    }
    
    // Update time display only (for when app is paused)
    function updateTimeDisplay() {
        // Update battery and time for display
        mData["battery"] = System.getSystemStats().battery;
        var now = System.getClockTime();
        mData["time"] = now.hour.format("%02d") + ":" + now.min.format("%02d");
        
        // Update total time (while accounting for pauses)
        var currentTime = System.getTimer();
        var elapsedMilliseconds = currentTime - mActivityStartTime;
        var elapsedSeconds = elapsedMilliseconds / 1000;
        mData["totalTime"] = elapsedSeconds;
        
        // If currently paused, don't include current pause in display
        if (mData["sessionPaused"]) {
            System.println("Currently paused - adjusting display time");
        }
    }
    
    // Reset foiling counters - can be called when needed
    function resetFoilingCounters() {
        mTotalDataPoints = 0;
        mFoilingDataPoints = 0;
        mData["percentOnFoil"] = 0.0;
        System.println("Foiling counters reset");
    }
    
    // Set the wind strength for this session
    function setWindStrength(index) {
        if (index >= 0 && index < WIND_STRENGTHS.size()) {
            mData["windStrength"] = WIND_STRENGTHS[index];
            mData["windStrengthIndex"] = index;
            mSessionStats["windStrength"] = WIND_STRENGTHS[index];
            return true;
        }
        return false;
    }
    
    // Store wind strength with timestamp
    function saveWindStrength(windStrength) {
        var storage = Application.Storage;
        
        // Store the wind strength with timestamp
        var windData = {
            "strength" => windStrength,
            "timestamp" => Time.now()
        };
        
        // Store alongside the session data
        storage.setValue("lastWindStrength", windData);
        
        // Also update the session stats for this model
        mSessionStats["windStrength"] = windStrength;
        
        // Update data field directly
        mData["windStrength"] = windStrength;
    }
    
    // Get the available wind strength options
    function getWindStrengthOptions() {
        return WIND_STRENGTHS;
    }
    
    // Check if there's been a significant change in speed to trigger UI update
    function hasSignificantChange() {
        var currentSpeed = mData["currentSpeed"];
        var diff = currentSpeed - mLastSignificantSpeed;
        if (diff < 0) {
            diff = -diff; // Absolute value (since we can't use Math.abs)
        }
        
        if (diff >= SIGNIFICANT_CHANGE) {
            mLastSignificantSpeed = currentSpeed;
            return true;
        }
        return false;
    }
    
    // Save activity data to storage
 // Ultra-simplified activity data save
// Save activity data to storage - restored full functionality with robust error handling
    function saveActivityData() {
        System.println("saveActivityData: Starting...");
        try {
            // Step 1: Get storage reference
            var storage = Application.Storage;
            System.println("Storage access successful");
            
            // Step 2: Create basic session info with mandatory fields
            var sessionInfo = {
                "date" => Time.now().value(),
                "maxSpeed" => 0.0f,
                "totalTime" => 0
            };
            
            // Step 3: Add primary data fields with individual error handling
            try {
                if (mData != null && mData.hasKey("maxSpeed")) {
                    sessionInfo["maxSpeed"] = mData["maxSpeed"].toFloat();
                }
            } catch (e) {
                System.println("Error adding maxSpeed: " + e.getErrorMessage());
            }
            
            try {
                if (mData != null && mData.hasKey("totalTime")) {
                    sessionInfo["totalTime"] = mData["totalTime"].toNumber();
                }
            } catch (e) {
                System.println("Error adding totalTime: " + e.getErrorMessage());
            }
            
            // Step 4: Add secondary data fields with individual error handling
            try {
                if (mData != null && mData.hasKey("max3sSpeed")) {
                    sessionInfo["max3sSpeed"] = mData["max3sSpeed"].toFloat();
                }
            } catch (e) {
                System.println("Error adding max3sSpeed: " + e.getErrorMessage());
            }
            
            try {
                if (mData != null && mData.hasKey("percentOnFoil")) {
                    sessionInfo["percentOnFoil"] = mData["percentOnFoil"].toFloat();
                }
            } catch (e) {
                System.println("Error adding percentOnFoil: " + e.getErrorMessage());
            }
            
            try {
                if (mData != null && mData.hasKey("windStrength")) {
                    var windStr = mData["windStrength"];
                    sessionInfo["windStrength"] = (windStr != null) ? windStr.toString() : "";
                }
            } catch (e) {
                System.println("Error adding windStrength: " + e.getErrorMessage());
                sessionInfo["windStrength"] = "";
            }
            
            // Step 5: Calculate derived values
            try {
                var avgSpeed = (sessionInfo["maxSpeed"] * 0.6f).toFloat();
                var timeHours = (sessionInfo["totalTime"] / 3600.0f).toFloat();
                var estDistance = (avgSpeed * timeHours).toFloat();
                
                sessionInfo["totalDistanceKm"] = estDistance;
                sessionInfo["avgSpeed"] = avgSpeed;
                System.println("Derived calculations successful");
            } catch (e) {
                System.println("Error in calculations: " + e.getErrorMessage());
                sessionInfo["totalDistanceKm"] = 0.0f;
                sessionInfo["avgSpeed"] = 0.0f;
            }
            
            // Step 6: Retrieve existing history with error handling
            var history = null;
            try {
                history = storage.getValue("sessionHistory");
                if (history == null) {
                    System.println("No existing history found, creating new array");
                    history = [];
                } else {
                    System.println("Retrieved existing history with " + history.size() + " entries");
                }
            } catch (e) {
                System.println("Error retrieving history: " + e.getErrorMessage());
                history = [];
            }
            
            // Step 7: Add current session to history
            try {
                history.add(sessionInfo);
                System.println("Added session to history successfully");
            } catch (e) {
                System.println("Error adding to history: " + e.getErrorMessage());
                // Attempt recovery - recreate history if corrupted
                try {
                    history = [sessionInfo];
                } catch (e2) {
                    System.println("Could not recreate history: " + e2.getErrorMessage());
                }
            }
            
            // Step 8: Trim history to keep only most recent sessions
            try {
                if (history.size() > 10) {
                    var newHistory = history.slice(history.size() - 10, history.size());
                    history = newHistory;
                    System.println("History trimmed to 10 entries");
                }
            } catch (e) {
                System.println("Error trimming history: " + e.getErrorMessage());
                // Don't throw error here - continue with untrimmed history
            }
            
            // Step 9: Save both individual session and history
            try {
                storage.setValue("lastSession", sessionInfo);
                System.println("Saved last session successfully");
            } catch (e) {
                System.println("Error saving lastSession: " + e.getErrorMessage());
            }
            
            try {
                storage.setValue("sessionHistory", history);
                System.println("Saved session history successfully");
            } catch (e) {
                System.println("Error saving history: " + e.getErrorMessage());
                // Try a simplified history save
                try {
                    var simpleHistory = [sessionInfo];
                    storage.setValue("sessionHistory", simpleHistory);
                    System.println("Saved simplified history");
                } catch (e2) {
                    System.println("Could not save any history: " + e2.getErrorMessage());
                }
            }
            
            System.println("Complete session save successful");
            return true;
        } catch (e) {
            // Global error handler
            System.println("Critical error in saveActivityData: " + e.getErrorMessage());
            
            // Emergency fallback save with minimal data
            try {
                var storage = Application.Storage;
                var minimalSession = {
                    "date" => Time.now().value(),
                    "emergency" => true
                };
                
                storage.setValue("emergency_session", minimalSession);
                System.println("Emergency fallback save succeeded");
                return false;
            } catch (e2) {
                System.println("Total save failure: " + e2.getErrorMessage());
                return false;
            }
        }
    }
    
    // Get current data
    function getData() {
        return mData;
    }
    
    // Save settings to persistent storage
    function saveSettings() {
        var storage = Application.Storage;
        storage.setValue("settings", mSettings);
    }
    
    // Load settings from persistent storage
    function loadSettings() {
        var storage = Application.Storage;
        mSettings = storage.getValue("settings");
        
        if (mSettings == null) {
            // Default settings if nothing saved
            mSettings = {
                "backgroundColor" => Graphics.COLOR_BLACK,
                "foregroundColor" => Graphics.COLOR_WHITE,
                "foilingThreshold" => FOILING_THRESHOLD
            };
        }
    }

    // Add these new methods to the FoilTrackerModel class

    // New method to get lap data for recording
    function getLapData() {
        // Create a structure with all the lap data
        var lapData = {
            "percentOnFoil" => 0,
            "vmgUp" => 0.0,
            "vmgDown" => 0.0,
            "tackSec" => 0.0,
            "tackMtr" => 0.0,
            "avgTackAngle" => 0
        };
        
        // Fill in the current values
        if (mData.hasKey("percentOnFoil")) {
            lapData["percentOnFoil"] = mData["percentOnFoil"].toNumber();
        }
        
        // For the other values, we'll need to access them from external sources
        // like the WindTracker, so this will be passed to that class to fill in
        
        // Return the data structure
        return lapData;
    }

    // New method to calculate time since last tack
    function getTimeSinceLastTack() {
        // This would use timing information to calculate seconds since last tack
        // For now, return a placeholder value - this should be implemented
        // by tracking the timestamp of the last tack in WindTracker
        return 0.0;
    }

    // New method to calculate distance since last tack
    function getDistanceSinceLastTack() {
        // This would use position data to calculate meters since last tack
        // For now, return a placeholder value - this should be implemented
        // by tracking the position of the last tack in WindTracker
        return 0.0;
    }
}