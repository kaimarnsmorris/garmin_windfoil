using Toybox.System;
using Toybox.Math;
using Toybox.Time;
using Toybox.Lang;

// Constants for debug mode
const DEBUG_MODE = true;  // Set to false for production builds

// Helper function for debug logging
function log(message) {
    if (DEBUG_MODE) {
        System.println(message);
    }
}

// WindTracker class for VMG calculations and tack/gybe detection
class WindTracker {
    // Constants for tack/gybe detection
    private const HEADING_BUFFER_SIZE = 10;         // Store recent headings
    private const MANEUVER_THRESHOLD = 10;          // Threshold to detect maneuver across wind line
    private const MAX_MANEUVERS = 100;              // Maximum number of maneuvers to track
    private const COG_SMOOTHING_FACTOR = 0.15;      // Smoothing factor for COG (higher = more responsive)
    private const VMG_SMOOTHING_FACTOR = 0.1;       // Smoothing factor for VMG (lower = smoother)
    
    // Constants for time-based maneuver angle calculation
    private const MAN_ANGLE_TIME_MEASURE = 10;      // Time period to measure course (seconds)
    private const MAN_ANGLE_TIME_IGNORE = 2;        // Time to ignore immediately before/after maneuver (seconds)
    private const HEADING_HISTORY_SIZE = 60;        // Store 60 seconds of heading history
    
    // Class variables
    private var mWindDirection;             // Current wind direction (degrees)
    private var mInitialWindDirection;      // User-specified initial wind direction
    private var mAutoWindDetection;         // Whether auto wind detection is active
    private var mWindDirectionLocked;       // Whether wind direction is locked
    private var mHeadingBuffer;             // Buffer for recent headings
    private var mBufferIndex;               // Current index in heading buffer
    private var mLastSignificantHeading;    // Last heading before maneuver
    private var mTackCount;                 // Number of tacks
    private var mGybeCount;                 // Number of gybes
    private var mLastTackAngle;             // Most recent tack angle
    private var mLastGybeAngle;             // Most recent gybe angle
    private var mCurrentVMG;                // Current velocity made good
    private var mIsStbdTack;                // True if on starboard tack, false if on port
    private var mIsUpwind;                  // True if sailing upwind, false if downwind
    private var mLastTackHeadings;          // Store headings from recent tacks
    private var mLastGybeHeadings;          // Store headings from recent gybes
    private var mWindAngleLessCOG;          // Normalized wind angle less COG (-180 to 180)
    private var mLastWindAngleLessCOG;      // Previous wind angle for maneuver detection
    private var mManeuverHistory;           // Array to store maneuver history
    private var mManeuverStats;             // Dictionary to store maneuver statistics
    private var mSmoothedCOG;               // Smoothed Course Over Ground
    private var mPrevSmoothedCOG;           // Previous smoothed COG value
    
    // New variables for time-based maneuver angle calculation
    private var mHeadingHistory;            // Array to store recent heading history with timestamps
    private var mHeadingHistoryIndex;       // Current index in heading history
    private var mManeuverTimestamp;         // Timestamp when maneuver was detected
    private var mPendingManeuver;           // Information about a pending maneuver to calculate angle
    
    function initialize() {
        resetData();
    }
    
    // Reset data structures
    function resetData() {
        mWindDirection = 0;
        mInitialWindDirection = 0;
        mAutoWindDetection = false;
        mWindDirectionLocked = false;
        
        // Initialize heading buffer
        mHeadingBuffer = new [HEADING_BUFFER_SIZE];
        for (var i = 0; i < HEADING_BUFFER_SIZE; i++) {
            mHeadingBuffer[i] = 0;
        }
        mBufferIndex = 0;
        
        mLastSignificantHeading = 0;
        mTackCount = 0;
        mGybeCount = 0;
        mLastTackAngle = 0;
        mLastGybeAngle = 0;
        mCurrentVMG = 0.0;
        mIsStbdTack = false;
        mIsUpwind = false;
        mWindAngleLessCOG = 0;
        mLastWindAngleLessCOG = 0;
        mSmoothedCOG = 0;
        mPrevSmoothedCOG = 0;
        
        // Initialize arrays for recent tack/gybe headings
        mLastTackHeadings = [0, 0];
        mLastGybeHeadings = [0, 0];
        
        // Initialize maneuver history and stats
        mManeuverHistory = new [MAX_MANEUVERS];
        mManeuverStats = {
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "maxTackAngle" => 0,
            "maxGybeAngle" => 0
        };
        
        // Initialize new data structures for time-based angle calculation
        mHeadingHistory = new [HEADING_HISTORY_SIZE];
        for (var i = 0; i < HEADING_HISTORY_SIZE; i++) {
            mHeadingHistory[i] = {
                "heading" => 0,
                "timestamp" => 0,
                "valid" => false
            };
        }
        mHeadingHistoryIndex = 0;
        mManeuverTimestamp = 0;
        mPendingManeuver = null;
    }
    
    // Set initial wind direction from user input
    function setInitialWindDirection(angle) {
        mInitialWindDirection = angle;
        mWindDirection = angle;
        mAutoWindDetection = false;
        
        // Reset counters when wind direction is manually set
        mTackCount = 0;
        mGybeCount = 0;
        mLastTackAngle = 0;
        mLastGybeAngle = 0;
        
        // Set last significant heading to null to avoid immediate maneuver detection
        mLastSignificantHeading = 0;
        
        log("Initial wind direction set to: " + angle);
    }
    
    // Reset to manual wind direction
    function resetToManualDirection() {
        mWindDirection = mInitialWindDirection;
        mAutoWindDetection = false;
        mWindDirectionLocked = false;
        mTackCount = 0;
        mGybeCount = 0;
        mLastTackAngle = 0;
        mLastGybeAngle = 0;
        log("Reset to manual wind direction: " + mInitialWindDirection);
    }
    
    // Lock the wind direction at its current value
    function lockWindDirection() {
        mWindDirectionLocked = true;
        log("Wind direction locked at: " + mWindDirection);
    }
    
    // Unlock the wind direction
    function unlockWindDirection() {
        mWindDirectionLocked = false;
        log("Wind direction unlocked");
    }
    
    // Process position data to detect tacks/gybes and calculate VMG
    function processPositionData(info) {
        // Ensure we have valid data
        if (info == null) {
            return;
        }
        
        // Check if heading and speed properties exist and are not null
        var hasHeading = (info has :heading && info.heading != null);
        var hasSpeed = (info has :speed && info.speed != null);
        
        if (!hasHeading || !hasSpeed) {
            return;
        }
        
        var heading = info.heading.toFloat();
        var speed = info.speed * 1.943844; // Convert m/s to knots
        
        // Convert heading from radians to degrees if needed
        // Position.Info provides heading in radians according to Garmin documentation
        if (heading < 2 * Math.PI) {
            heading = Math.toDegrees(heading);
        }
        
        // Normalize heading to 0-360 range
        heading = normalizeAngle(heading);
        
        // Apply smoothing to COG (Exponential Moving Average)
        var smoothedHeading = applyCOGSmoothing(heading);
        
        // Get current timestamp
        var currentTime = System.getTimer();
        
        // Store the smoothed heading in history
        storeHeadingHistory(smoothedHeading, currentTime);
        
        // Log position data
        log("Position Data - COG: " + heading + "°, Smoothed COG: " + smoothedHeading + "°, Speed: " + speed + " kts");
        
        // Add heading to rolling buffer
        if (mBufferIndex < HEADING_BUFFER_SIZE) {
            mHeadingBuffer[mBufferIndex] = smoothedHeading;
            mBufferIndex = (mBufferIndex + 1) % HEADING_BUFFER_SIZE;
        }
        
        // Store previous values for comparison
        mLastWindAngleLessCOG = mWindAngleLessCOG;
        
        // Calculate wind angle less COG (-180 to 180) using smoothed heading
        calculateWindAngleLessCOG(smoothedHeading);
        
        // Initialize tack and point of sail if this is first valid data point
        if (mLastWindAngleLessCOG == 0) {
            initializeTackAndPointOfSail();
        } else {
            // Check for tack/gybe maneuver
            detectManeuver(smoothedHeading, speed, currentTime);
        }
        
        // Check for pending maneuver angle calculation
        checkPendingManeuverAngle(currentTime);
        
        // Determine upwind/downwind status
        determinePointOfSail();
        
        // Calculate VMG
        calculateVMG(heading, speed);
        
        // Automatically update wind direction after 2 tacks or 2 gybes
        updateAutoWindDirection();
        
        // Update last significant heading if needed
        if (mLastSignificantHeading == 0) {
            mLastSignificantHeading = smoothedHeading;
        }
    }
    
    // Store heading in history array with timestamp
    function storeHeadingHistory(heading, timestamp) {
        // We store the smoothed heading (which already has EMA applied)
        mHeadingHistory[mHeadingHistoryIndex] = {
            "heading" => heading, // This is already the smoothed heading with EMA applied
            "timestamp" => timestamp,
            "valid" => true
        };
        
        // Increment index with wrap-around
        mHeadingHistoryIndex = (mHeadingHistoryIndex + 1) % HEADING_HISTORY_SIZE;
    }
    
    // Apply COG smoothing using Exponential Moving Average
    function applyCOGSmoothing(rawHeading) {
        // First time initialization
        if (mSmoothedCOG == 0) {
            mSmoothedCOG = rawHeading;
            mPrevSmoothedCOG = rawHeading;
            return rawHeading;
        }
        
        // Store previous smoothed value
        mPrevSmoothedCOG = mSmoothedCOG;
        
        // Handle the case where heading crosses the 0/360 boundary
        // This ensures we smooth correctly across the boundary
        var delta = rawHeading - mSmoothedCOG;
        if (delta > 180) {
            delta -= 360;
        } else if (delta < -180) {
            delta += 360;
        }
        
        // Apply Exponential Moving Average
        mSmoothedCOG = normalizeAngle(mSmoothedCOG + (COG_SMOOTHING_FACTOR * delta));
        
        return mSmoothedCOG;
    }
    
    // Calculate wind angle less COG and normalize to -180 to 180
    function calculateWindAngleLessCOG(heading) {
        // Wind angle less COG
        var windAngle = mWindDirection - heading;
        
        // Normalize to -180 to 180
        if (windAngle > 180) {
            windAngle -= 360;
        } else if (windAngle <= -180) {
            windAngle += 360;
        }
        
        mWindAngleLessCOG = windAngle;
        log("Wind angle less COG: " + mWindAngleLessCOG + "°");
    }
    
    // Initialize tack and point of sail based on first wind angle
    function initializeTackAndPointOfSail() {
        // Initialize starboard/port tack based on wind angle
        // Positive wind angle means wind is on starboard side = starboard tack
        // Negative wind angle means wind is on port side = port tack
        mIsStbdTack = (mWindAngleLessCOG >= 0);
        
        // Initialize upwind/downwind
        // Upwind if wind angle is between -90 and 90 degrees
        mIsUpwind = (mWindAngleLessCOG > -90 && mWindAngleLessCOG < 90);
        
        log("Initialized tack: " + (mIsStbdTack ? "Starboard" : "Port") + 
                      ", Point of sail: " + (mIsUpwind ? "Upwind" : "Downwind") +
                      ", WindAngleLessCOG: " + mWindAngleLessCOG);
    }
    
    // Determine current point of sail (upwind/downwind)
    function determinePointOfSail() {
        // Determine if upwind or downwind based on absolute wind angle
        // Upwind if wind angle is between -90 and 90 degrees
        var newUpwind = (mWindAngleLessCOG > -90 && mWindAngleLessCOG < 90);
        
        // If point of sail changed, log it
        if (mIsUpwind != newUpwind) {
            log("Point of sail changed from " + (mIsUpwind ? "Upwind" : "Downwind") + 
                " to " + (newUpwind ? "Upwind" : "Downwind") + 
                " (WindAngle: " + mWindAngleLessCOG + "°)");
            mIsUpwind = newUpwind;
        }
    }
    
    // Detect tacks and gybes based on crossing thresholds
    function detectManeuver(heading, speed, currentTime) {
        // Use a lowered speed threshold (2.0 knots) to detect more maneuvers
        var speedThreshold = 2.0;
        
        // Try to get the model from app to access settings
        var app = Application.getApp();
        if (app != null) {
            // Check if the app has a properly initialized model
            if (app has :mModel && app.mModel != null) {
                // Get the settings from the model
                var data = app.mModel.getData();
                if (data != null && data.hasKey("settings")) {
                    var settings = data["settings"];
                    if (settings != null && settings.hasKey("foilingThreshold")) {
                        speedThreshold = settings["foilingThreshold"];
                        log("Using speed threshold from settings: " + speedThreshold);
                    }
                }
            }
        }
        
        // Only detect maneuvers above speed threshold
        if (speed < speedThreshold) {
            return;
        }
        
        var maneuverDetected = false;
        var isTack = false;  // Boolean flag for tack vs gybe
        var oldTack = mIsStbdTack;
        
        // Check for tack/gybe based on current tack and wind angle thresholds
        if (mIsStbdTack) {
            // Currently on starboard tack (wind from starboard side, positive angle)
            
            // Check for tack (crossing through head-to-wind)
            if (mWindAngleLessCOG < -MANEUVER_THRESHOLD) {
                mIsStbdTack = false; // Now on port tack
                maneuverDetected = true;
                isTack = true;  // Initial classification
                log("Tack changed from Starboard to Port (WindAngle: " + mWindAngleLessCOG + ")");
            } 
            // Check for gybe (crossing through downwind)
            else if (mWindAngleLessCOG < (-180 + MANEUVER_THRESHOLD) && !mIsUpwind) {
                mIsStbdTack = false; // Now on port tack
                maneuverDetected = true;
                isTack = false;  // Initial classification
                log("Gybe detected - crossed through downwind from Starboard to Port (WindAngle: " + mWindAngleLessCOG + ")");
            }
        } else {
            // Currently on port tack (wind from port side, negative angle)
            
            // Check for tack (crossing through head-to-wind)
            if (mWindAngleLessCOG > MANEUVER_THRESHOLD) {
                mIsStbdTack = true; // Now on starboard tack
                maneuverDetected = true;
                isTack = true;  // Initial classification
                log("Tack changed from Port to Starboard (WindAngle: " + mWindAngleLessCOG + ")");
            } 
            // Check for gybe (crossing through downwind)
            else if (mWindAngleLessCOG > (180 - MANEUVER_THRESHOLD) && !mIsUpwind) {
                mIsStbdTack = true; // Now on starboard tack
                maneuverDetected = true;
                isTack = false;  // Initial classification
                log("Gybe detected - crossed through downwind from Port to Starboard (WindAngle: " + mWindAngleLessCOG + ")");
            }
        }
        
        // If maneuver detected, start the process of angle calculation
        if (maneuverDetected) {
            // Determine maneuver type based on the wind angle before the maneuver
            // Use the LastWindAngleLessCOG since that represents what we were doing before this maneuver
            var lastUpwind = (mLastWindAngleLessCOG > -90 && mLastWindAngleLessCOG < 90);
            
            // Override maneuver type classification based on point of sail before maneuver
            // This is more reliable than the initial detection method
            isTack = lastUpwind; // If upwind, it's a tack; if downwind, it's a gybe
            
            // Log maneuver classification
            if (isTack) {
                log("Maneuver classified as Tack (was upwind, angle: " + mLastWindAngleLessCOG + ")");
            } else {
                log("Maneuver classified as Gybe (was downwind, angle: " + mLastWindAngleLessCOG + ")");
            }
            
            // Create pending maneuver record with isTack boolean
            mPendingManeuver = {
                "isTack" => isTack,  // Using boolean flag instead of string
                "timestamp" => currentTime,
                "lastWindAngle" => mLastWindAngleLessCOG,
                "oldTack" => oldTack,
                "newTack" => mIsStbdTack
            };
            
            // Store the maneuver timestamp
            mManeuverTimestamp = currentTime;
            
            log("Maneuver detected! Type: " + (isTack ? "Tack" : "Gybe") + 
                ", Timestamp: " + currentTime + 
                ", Last WindAngle: " + mLastWindAngleLessCOG + 
                ", Current WindAngle: " + mWindAngleLessCOG);
        }
    }
    
    // Check if we have a pending maneuver and enough time has passed to calculate the angle
    function checkPendingManeuverAngle(currentTime) {
        // If no pending maneuver, return
        if (mPendingManeuver == null || mManeuverTimestamp == 0) {
            return;
        }
        
        // Calculate time since maneuver
        var timeSinceManeuver = currentTime - mManeuverTimestamp;
        
        // Log for debugging
        log("Checking pending maneuver: type=" + (mPendingManeuver["isTack"] ? "Tack" : "Gybe") + 
            ", time passed=" + (timeSinceManeuver / 1000) + "s, need=" + 
            (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) + "s");
        
        // Wait until we have enough data after the maneuver (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE)
        if (timeSinceManeuver < (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000) {
            return;
        }
        
        // We have enough data, calculate the maneuver angle
        calculateManeuverAngle(mPendingManeuver);
        
        // Clear pending maneuver
        mPendingManeuver = null;
    }
    
    // Calculate maneuver angle based on heading history
    function calculateManeuverAngle(pendingManeuver) {
        var maneuverTimestamp = pendingManeuver["timestamp"];
        var isTack = pendingManeuver["isTack"];  // Boolean flag - true for tack, false for gybe
        var oldTack = pendingManeuver["oldTack"];
        var newTack = pendingManeuver["newTack"];
        
        log("Processing " + (isTack ? "Tack" : "Gybe") + " maneuver, Time: " + (maneuverTimestamp/1000) + "s");
        
        // Get timestamps for before maneuver period
        var beforeStart = maneuverTimestamp - (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000;
        var beforeEnd = maneuverTimestamp - MAN_ANGLE_TIME_IGNORE * 1000;
        
        // Get timestamps for after maneuver period
        var afterStart = maneuverTimestamp + MAN_ANGLE_TIME_IGNORE * 1000;
        var afterEnd = maneuverTimestamp + (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000;
        
        log("Time periods for measurement: Before " + (beforeStart/1000) + "-" + (beforeEnd/1000) + 
            "s, After " + (afterStart/1000) + "-" + (afterEnd/1000) + "s");
        
        // Calculate average heading before maneuver
        var beforeHeading = calculateAverageHeading(beforeStart, beforeEnd);
        
        // Calculate average heading after maneuver
        var afterHeading = calculateAverageHeading(afterStart, afterEnd);
        
        // Calculate the maneuver angle
        var maneuverAngle = 0;
        
        // Only proceed if we have enough data from both before and after the maneuver
        if (beforeHeading != null && afterHeading != null) {
            maneuverAngle = angleAbsDifference(beforeHeading, afterHeading);
            
            log("Maneuver Angle Calculation:");
            log("- Before heading (avg from " + MAN_ANGLE_TIME_IGNORE + "s to " + 
                (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) + "s before maneuver): " + beforeHeading);
            log("- After heading (avg from " + MAN_ANGLE_TIME_IGNORE + "s to " + 
                (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) + "s after maneuver): " + afterHeading);
            log("- Calculated " + (isTack ? "Tack" : "Gybe") + " angle: " + maneuverAngle);
            
            // Process based on the maneuver type boolean
            if (isTack) {
                // Increment tack counter
                mTackCount += 1;
                log("Incrementing tack count to: " + mTackCount);
                
                // Update last tack angle
                mLastTackAngle = maneuverAngle;
                
                // Record tack headings for auto wind calculation
                mLastTackHeadings[0] = mLastTackHeadings[1];
                mLastTackHeadings[1] = afterHeading;
                
                // Record maneuver in history with boolean
                recordManeuver(true, afterHeading, maneuverAngle);
                
                // Log tack headings for debugging
                log("Updated tack headings: [" + mLastTackHeadings[0] + ", " + mLastTackHeadings[1] + "]");
                log("Tack count: " + mTackCount);
            } 
            // Must be a gybe if not a tack
            else {
                // Increment gybe counter
                mGybeCount += 1;
                log("Incrementing gybe count to: " + mGybeCount);
                
                // Update last gybe angle
                mLastGybeAngle = maneuverAngle;
                
                // Record gybe headings for auto wind calculation
                mLastGybeHeadings[0] = mLastGybeHeadings[1];
                mLastGybeHeadings[1] = afterHeading;
                
                // Record maneuver in history with boolean
                recordManeuver(false, afterHeading, maneuverAngle);
                
                // Log gybe headings for debugging
                log("Updated gybe headings: [" + mLastGybeHeadings[0] + ", " + mLastGybeHeadings[1] + "]");
                log("Gybe count: " + mGybeCount);
            }
            
            // Update last significant heading
            mLastSignificantHeading = afterHeading;
        } else {
            log("Could not calculate " + (isTack ? "Tack" : "Gybe") + " angle - insufficient heading history data");
            
            // Let's provide the exact issue for debugging
            if (beforeHeading == null) {
                log("- Missing 'before' heading data");
            }
            if (afterHeading == null) {
                log("- Missing 'after' heading data");
            }
        }
    }
    
    // Calculate average heading over a time period
    function calculateAverageHeading(startTime, endTime) {
        var sumX = 0.0;
        var sumY = 0.0;
        var count = 0;
        
        // Loop through heading history to find entries within the time period
        for (var i = 0; i < HEADING_HISTORY_SIZE; i++) {
            var entry = mHeadingHistory[i];
            
            // Skip invalid entries
            if (!entry["valid"]) {
                continue;
            }
            
            var timestamp = entry["timestamp"];
            var heading = entry["heading"];
            
            // Check if entry is within the time period
            if (timestamp >= startTime && timestamp <= endTime) {
                // Convert heading to radians
                var rad = Math.toRadians(heading);
                
                // Add to vector components
                sumX += Math.cos(rad);
                sumY += Math.sin(rad);
                count++;
            }
        }
        
        // If no valid entries found, return null
        if (count == 0) {
            log("No valid heading entries found for time period: " + (startTime/1000) + "s to " + (endTime/1000) + "s");
            return null;
        }
        
        // Log count of samples
        log("Found " + count + " valid heading samples for averaging");
        
        // Calculate average vector
        var avgX = sumX / count;
        var avgY = sumY / count;
        
        // Calculate average heading in degrees
        var avgHeading = Math.toDegrees(Math.atan2(avgY, avgX));
        
        // Normalize to 0-360
        return normalizeAngle(avgHeading);
    }
    
    // Record maneuver in history
    function recordManeuver(isTack, heading, angle) {
        // Create maneuver record using the isTack boolean
        var maneuver = {
            "isTack" => isTack,
            "heading" => heading,
            "angle" => angle,
            "time" => Time.now().value()
        };
        
        // Calculate index based on current count
        var index = -1;
        if (isTack) {
            index = mTackCount - 1;
            log("Recording tack at index " + index + " with angle " + angle);
        } else {
            index = mGybeCount - 1;
            log("Recording gybe at index " + index + " with angle " + angle);
        }
        
        // Double-check to ensure index is valid
        if (index >= 0 && index < MAX_MANEUVERS) {
            mManeuverHistory[index] = maneuver;
            
            // Update statistics
            updateManeuverStats();
        } else {
            log("Warning: Maneuver index out of bounds: " + index);
        }
    }
    
    // Update maneuver statistics
    function updateManeuverStats() {
        var tackCount = 0;
        var gybeCount = 0;
        var tackSum = 0;
        var gybeSum = 0;
        var maxTack = 0;
        var maxGybe = 0;
        
        // Loop through history and calculate stats
        for (var i = 0; i < MAX_MANEUVERS; i++) {
            if (mManeuverHistory[i] != null) {
                var maneuver = mManeuverHistory[i];
                
                // Check if it's a tack or gybe using the boolean flag
                if (maneuver["isTack"]) {
                    tackCount++;
                    tackSum += maneuver["angle"];
                    if (maneuver["angle"] > maxTack) {
                        maxTack = maneuver["angle"];
                    }
                } else {
                    gybeCount++;
                    gybeSum += maneuver["angle"];
                    if (maneuver["angle"] > maxGybe) {
                        maxGybe = maneuver["angle"];
                    }
                }
            }
        }
        
        // Calculate averages
        var avgTack = (tackCount > 0) ? tackSum / tackCount : 0;
        var avgGybe = (gybeCount > 0) ? gybeSum / gybeCount : 0;
        
        // Update stats
        mManeuverStats = {
            "avgTackAngle" => avgTack,
            "avgGybeAngle" => avgGybe,
            "maxTackAngle" => maxTack,
            "maxGybeAngle" => maxGybe
        };
        
        // Log updated stats
        log("Updated maneuver stats: TackCount=" + tackCount + ", GybeCount=" + gybeCount);
    }
    
    // Calculate VMG with smoothing
    function calculateVMG(heading, speed) {
        if (speed <= 0) {
            mCurrentVMG = 0.0;
            return;
        }
        
        // Get wind angle (absolute value for calculation)
        var absWindAngle = mWindAngleLessCOG;
        if (absWindAngle < 0) {
            absWindAngle = -absWindAngle; // Manual absolute value
        }
        
        // Calculate raw VMG
        var windAngleRad;
        var rawVMG;
        
        if (mIsUpwind) {
            // Upwind calculation
            windAngleRad = Math.toRadians(absWindAngle);
            rawVMG = speed * Math.cos(windAngleRad);
        } else {
            // Downwind calculation
            windAngleRad = Math.toRadians(180 - absWindAngle);
            rawVMG = speed * Math.cos(windAngleRad);
        }
        
        // Ensure VMG is always positive (we're showing speed TO the wind or AWAY from the wind)
        if (rawVMG < 0) {
            rawVMG = -rawVMG;
        }
        
        // Apply smoothing to VMG using Exponential Moving Average
        if (mCurrentVMG > 0) {
            mCurrentVMG = (mCurrentVMG * (1.0 - VMG_SMOOTHING_FACTOR)) + (rawVMG * VMG_SMOOTHING_FACTOR);
        } else {
            mCurrentVMG = rawVMG;
        }
        
        // Log VMG calculation - use actual windAngleLessCOG not abs value
        log("VMG Calculation - Wind: " + mWindDirection + "°, COG: " + mSmoothedCOG + 
                       "°, WindAngle: " + mWindAngleLessCOG + "°, PointOfSail: " + (mIsUpwind ? "Upwind" : "Downwind") + 
                       ", Tack: " + (mIsStbdTack ? "Starboard" : "Port") + 
                       ", VMG: " + mCurrentVMG.format("%.2f") + " kts");
    }
    
    // Update wind direction automatically based on tack/gybe pattern
    function updateAutoWindDirection() {
        // Skip if wind direction is locked
        if (mWindDirectionLocked) {
            return;
        }
        
        var shouldUpdate = false;
        var newWindDirection = mWindDirection;
        
        // Use tack headings if we have 2 consecutive tacks
        if (mTackCount >= 2) {
            var heading1 = mLastTackHeadings[0];
            var heading2 = mLastTackHeadings[1];
            
            // Only update if both headings are valid (non-zero)
            if (heading1 != 0 && heading2 != 0) {
                // Calculate bisector angle between the two tack headings
                var bisector = calculateBisectorAngle(heading1, heading2);
                newWindDirection = bisector;
                
                // Log detailed calculation
                log("Auto wind calculation from tacks:");
                log("- Heading 1: " + heading1 + "°");
                log("- Heading 2: " + heading2 + "°");
                log("- Calculated bisector: " + bisector + "°");
                
                // Check if the new wind direction is significantly different from current (> 120°)
                // This would indicate a possible 180° error that needs correction
                var windDiff = angleAbsDifference(newWindDirection, mWindDirection);
                if (windDiff > 120) {
                    // Adjust by 180° to get the correct orientation
                    newWindDirection = normalizeAngle(newWindDirection + 180);
                    log("- Wind direction adjusted by 180° due to large difference: " + newWindDirection + "°");
                }
                
                shouldUpdate = true;
            }
        }
        // Or use gybe headings if we have 2 consecutive gybes
        else if (mGybeCount >= 2) {
            var heading1 = mLastGybeHeadings[0];
            var heading2 = mLastGybeHeadings[1];
            
            // Only update if both headings are valid (non-zero)
            if (heading1 != 0 && heading2 != 0) {
                // Calculate bisector angle, then add 180 degrees (downwind)
                var bisector = calculateBisectorAngle(heading1, heading2);
                newWindDirection = normalizeAngle(bisector + 180);
                
                // Log detailed calculation
                log("Auto wind calculation from gybes:");
                log("- Heading 1: " + heading1 + "°");
                log("- Heading 2: " + heading2 + "°");
                log("- Calculated bisector: " + bisector + "°");
                log("- Wind direction (bisector + 180°): " + newWindDirection + "°");
                
                // Check if the new wind direction is significantly different from current (> 120°)
                // This would indicate a possible 180° error that needs correction
                var windDiff = angleAbsDifference(newWindDirection, mWindDirection);
                if (windDiff > 120) {
                    // Adjust by 180° to get the correct orientation
                    newWindDirection = normalizeAngle(newWindDirection + 180);
                    log("- Wind direction adjusted by 180° due to large difference: " + newWindDirection + "°");
                }
                
                shouldUpdate = true;
            }
        }
        
        // Update wind direction if conditions met
        if (shouldUpdate) {
            mWindDirection = newWindDirection;
            mAutoWindDetection = true;
            log("Auto wind direction updated to: " + newWindDirection);
        }
    }
    
    // Calculate bisector angle between two headings
    function calculateBisectorAngle(angle1, angle2) {
        // Convert to radians
        var rad1 = Math.toRadians(angle1);
        var rad2 = Math.toRadians(angle2);
        
        // Calculate cartesian coordinates
        var x1 = Math.cos(rad1);
        var y1 = Math.sin(rad1);
        var x2 = Math.cos(rad2);
        var y2 = Math.sin(rad2);
        
        // Calculate average vector
        var avgX = (x1 + x2) / 2;
        var avgY = (y1 + y2) / 2;
        
        // Check for zero vector (shouldn't happen, but just in case)
        if ((avgX < 0.00001 && avgX > -0.00001) && (avgY < 0.00001 && avgY > -0.00001)) {
            return 0;
        }
        
        // Convert back to angle - use safe atan2 implementation
        var avgAngle = 0;
        if (avgX > 0) {
            avgAngle = Math.toDegrees(Math.atan(avgY / avgX));
        } else if (avgX < 0 && avgY >= 0) {
            avgAngle = Math.toDegrees(Math.atan(avgY / avgX)) + 180;
        } else if (avgX < 0 && avgY < 0) {
            avgAngle = Math.toDegrees(Math.atan(avgY / avgX)) - 180;
        } else if ((avgX < 0.00001 && avgX > -0.00001) && avgY > 0) {
            avgAngle = 90;
        } else if ((avgX < 0.00001 && avgX > -0.00001) && avgY < 0) {
            avgAngle = -90;
        }
        
        // Normalize to 0-360
        return normalizeAngle(avgAngle);
    }
    
    // Helper function to get absolute angle difference
    function angleAbsDifference(angle1, angle2) {
        // Normalize angles to 0-360
        angle1 = normalizeAngle(angle1);
        angle2 = normalizeAngle(angle2);
        
        // Calculate difference
        var diff = angle1 - angle2;
        if (diff < 0) {
            diff = -diff;  // This is how to get absolute value without Math.abs
        }
        
        // Take the smaller angle
        if (diff > 180) {
            diff = 360 - diff;
        }
        
        return diff;
    }
    
    // Helper function to normalize angle to 0-360 range
    function normalizeAngle(angle) {
        while (angle < 0) {
            angle += 360;
        }
        while (angle >= 360) {
            angle -= 360;
        }
        return angle;
    }
    
    // Get current wind data
    function getWindData() {
        // Get current tack and point of sail as strings
        var tackStr = mIsStbdTack ? "Starboard" : "Port";
        var pointOfSailStr = mIsUpwind ? "Upwind" : "Downwind";
        
        // Get tack display text and color ID
        var tackDisplayStr = mIsStbdTack ? "Stb" : "Prt";
        var tackColorId = mIsStbdTack ? 1 : 2;  // 1 = green, 2 = red
        
        if (DEBUG_MODE) {
            log("WindTracker.getWindData() - Wind: " + mWindDirection + 
                 ", VMG: " + mCurrentVMG + 
                 ", Tack: " + tackStr +
                 ", TackCount: " + mTackCount +
                 ", GybeCount: " + mGybeCount);
        }
        
        try {
            return {
                "windDirection" => mWindDirection,
                "initialWindDirection" => mInitialWindDirection,
                "autoWindDetection" => mAutoWindDetection,
                "windDirectionLocked" => mWindDirectionLocked,
                "currentVMG" => mCurrentVMG,
                "tackCount" => mTackCount,
                "gybeCount" => mGybeCount,
                "lastTackAngle" => mLastTackAngle,
                "lastGybeAngle" => mLastGybeAngle,
                "currentTack" => tackStr,
                "currentPointOfSail" => pointOfSailStr,
                "windAngleLessCOG" => mWindAngleLessCOG,
                "tackDisplayText" => tackDisplayStr,
                "tackColorId" => tackColorId,
                "maneuverStats" => mManeuverStats,
                "valid" => true
            };
        } catch (ex) {
            log("Error in getWindData: " + ex.getErrorMessage());
            return {
                "windDirection" => mWindDirection,
                "initialWindDirection" => mInitialWindDirection,
                "currentVMG" => mCurrentVMG,
                "tackCount" => mTackCount,
                "gybeCount" => mGybeCount,
                "currentTack" => tackStr,
                "currentPointOfSail" => pointOfSailStr,
                "tackDisplayText" => tackDisplayStr,
                "tackColorId" => tackColorId,
                "valid" => true
            };
        }
    }
    
    // Get absolute value of wind angle
    function getAbsWindAngle() {
        var absAngle = mWindAngleLessCOG;
        if (absAngle < 0) {
            absAngle = -absAngle;
        }
        return absAngle;
    }
}