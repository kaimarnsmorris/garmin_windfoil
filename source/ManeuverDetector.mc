// ManeuverDetector.mc - Detects tacks and gybes
using Toybox.Time;
using Toybox.System;

class ManeuverDetector {
    // Constants
    private const MAN_ANGLE_TIME_MEASURE = 10;  // Time period to measure course (seconds)
    private const MAN_ANGLE_TIME_IGNORE = 2;    // Time to ignore before/after maneuver (seconds)
    
    // Properties
    private var mParent;                  // Reference to WindTracker parent
    private var mTackCount;               // Number of tacks
    private var mGybeCount;               // Number of gybes
    private var mLastTackAngle;           // Most recent tack angle
    private var mLastGybeAngle;           // Most recent gybe angle
    private var mLastTackHeadings;        // Recent tack headings [previous, current]
    private var mLastGybeHeadings;        // Recent gybe headings [previous, current]
    private var mManeuverHistory;         // Array to store maneuver history
    private var mManeuverStats;           // Statistics on maneuvers
    private var mManeuverTimestamp;       // Timestamp of last maneuver detection
    private var mPendingManeuver;         // Information about pending maneuver
    
    // Initialize
    function initialize(parent) {
        mParent = parent;
        reset();
    }
    
    // Reset detector
    function reset() {
        resetManeuverCounts();
        
        // Initialize maneuver history and stats
        mManeuverHistory = new [mParent.MAX_MANEUVERS];
        
        mManeuverStats = {
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "maxTackAngle" => 0,
            "maxGybeAngle" => 0
        };
        
        mManeuverTimestamp = 0;
        mPendingManeuver = null;
        
        log("ManeuverDetector reset");
    }
    
    // Reset just the counters (used when wind direction changes)
    function resetManeuverCounts() {
        mTackCount = 0;
        mGybeCount = 0;
        mLastTackAngle = 0;
        mLastGybeAngle = 0;
        mLastTackHeadings = [0, 0];
        mLastGybeHeadings = [0, 0];
        
        log("ManeuverDetector counters reset");
    }
    
    // Detect maneuvers based on angle changes
    function detectManeuver(heading, speed, currentTime, isStbdTack, isUpwind, windAngleLessCOG) {
        // Use a lower speed threshold for maneuver detection
        var speedThreshold = 2.0;
        
        // Try to get from settings if available
        try {
            var app = Application.getApp();
            if (app != null && app has :mModel && app.mModel != null) {
                var data = app.mModel.getData();
                if (data != null && data.hasKey("settings")) {
                    var settings = data["settings"];
                    if (settings != null && settings.hasKey("foilingThreshold")) {
                        speedThreshold = settings["foilingThreshold"];
                    }
                }
            }
        } catch (e) {
            log("Error getting speed threshold: " + e.getErrorMessage());
        }
        
        // Only detect maneuvers above speed threshold
        if (speed < speedThreshold) {
            return false;
        }
        
        var maneuverDetected = false;
        var isTack = false;  // Boolean flag for tack vs gybe
        var oldTack = isStbdTack;
        
        // Get the previous wind angle for comparison
        var lastWindAngleLessCOG = mParent.getAngleCalculator().getLastWindAngleLessCOG();
        
        // Check for tack/gybe based on tack and wind angle thresholds
        if (isStbdTack) {
            // Currently on starboard tack
            if (windAngleLessCOG < -mParent.MANEUVER_THRESHOLD) {
                // Tack to port
                mParent.getAngleCalculator().setStarboardTack(false);
                maneuverDetected = true;
                isTack = true;
                log("Tack changed from Starboard to Port (WindAngle: " + windAngleLessCOG + ")");
            } 
            else if (windAngleLessCOG < (-180 + mParent.MANEUVER_THRESHOLD) && !isUpwind) {
                // Gybe to port
                mParent.getAngleCalculator().setStarboardTack(false);
                maneuverDetected = true;
                isTack = false;
                log("Gybe detected from Starboard to Port (WindAngle: " + windAngleLessCOG + ")");
            }
        } else {
            // Currently on port tack
            if (windAngleLessCOG > mParent.MANEUVER_THRESHOLD) {
                // Tack to starboard
                mParent.getAngleCalculator().setStarboardTack(true);
                maneuverDetected = true;
                isTack = true;
                log("Tack changed from Port to Starboard (WindAngle: " + windAngleLessCOG + ")");
            } 
            else if (windAngleLessCOG > (180 - mParent.MANEUVER_THRESHOLD) && !isUpwind) {
                // Gybe to starboard
                mParent.getAngleCalculator().setStarboardTack(true);
                maneuverDetected = true;
                isTack = false;
                log("Gybe detected from Port to Starboard (WindAngle: " + windAngleLessCOG + ")");
            }
        }
        
        // If maneuver detected, start processing
        if (maneuverDetected) {
            // Determine maneuver type based on previous wind angle
            var lastUpwind = (lastWindAngleLessCOG > -90 && lastWindAngleLessCOG < 90);
            
            // Better classification based on point of sail
            isTack = lastUpwind;  // If upwind, it's a tack; if downwind, it's a gybe
            
            log("Maneuver classified as " + (isTack ? "Tack" : "Gybe") + 
                " (was " + (lastUpwind ? "upwind" : "downwind") + 
                ", angle: " + lastWindAngleLessCOG + ")");
            
            // Create pending maneuver record
            mPendingManeuver = {
                "isTack" => isTack,
                "timestamp" => currentTime,
                "lastWindAngle" => lastWindAngleLessCOG,
                "oldTack" => oldTack,
                "newTack" => !oldTack
            };
            
            // Store maneuver timestamp
            mManeuverTimestamp = currentTime;
            
            log("Maneuver detected! Type: " + (isTack ? "Tack" : "Gybe") + 
                ", Timestamp: " + currentTime);
            
            return true;
        }
        
        return false;
    }
    
    // Check for pending maneuvers that need angle calculation
    function checkPendingManeuvers(currentTime) {
        // If no pending maneuver, return
        if (mPendingManeuver == null || mManeuverTimestamp == 0) {
            return;
        }
        
        // Calculate time since maneuver
        var timeSinceManeuver = currentTime - mManeuverTimestamp;
        
        // Wait until we have enough data after the maneuver
        if (timeSinceManeuver < (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000) {
            return;
        }
        
        // We have enough data, calculate maneuver angle
        calculateManeuverAngle(mPendingManeuver);
        
        // Clear pending maneuver
        mPendingManeuver = null;
    }
    
    // Calculate maneuver angle based on heading history
    function calculateManeuverAngle(pendingManeuver) {
        var maneuverTimestamp = pendingManeuver["timestamp"];
        var isTack = pendingManeuver["isTack"];
        
        // Calculate time periods for measurement
        var beforeStart = maneuverTimestamp - (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000;
        var beforeEnd = maneuverTimestamp - MAN_ANGLE_TIME_IGNORE * 1000;
        var afterStart = maneuverTimestamp + MAN_ANGLE_TIME_IGNORE * 1000;
        var afterEnd = maneuverTimestamp + (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000;
        
        // Calculate headings before and after maneuver
        var beforeHeading = mParent.getAngleCalculator().calculateAverageHeading(beforeStart, beforeEnd);
        var afterHeading = mParent.getAngleCalculator().calculateAverageHeading(afterStart, afterEnd);
        
        // If we don't have enough data, bail out
        if (beforeHeading == null || afterHeading == null) {
            log("Cannot calculate " + (isTack ? "tack" : "gybe") + 
                " angle - insufficient heading history data");
            return;
        }
        
        // Calculate maneuver angle
        var maneuverAngle = mParent.getAngleCalculator().angleAbsDifference(beforeHeading, afterHeading);
        
        log("Maneuver Angle Calculation:");
        log("- Before heading: " + beforeHeading);
        log("- After heading: " + afterHeading);
        log("- Calculated " + (isTack ? "Tack" : "Gybe") + " angle: " + maneuverAngle);
        
        // Process based on maneuver type
        if (isTack) {
            // Increment tack counter
            mTackCount += 1;
            
            // Update last tack angle
            mLastTackAngle = maneuverAngle;
            
            // Record tack headings for auto wind calculation
            mLastTackHeadings[0] = mLastTackHeadings[1];
            mLastTackHeadings[1] = afterHeading;
            
            // Record maneuver in history
            recordManeuver(true, afterHeading, maneuverAngle);
            
            log("Tack recorded: #" + mTackCount + ", angle: " + maneuverAngle + "°");
        } else {
            // Increment gybe counter
            mGybeCount += 1;
            
            // Update last gybe angle
            mLastGybeAngle = maneuverAngle;
            
            // Record gybe headings for auto wind calculation
            mLastGybeHeadings[0] = mLastGybeHeadings[1];
            mLastGybeHeadings[1] = afterHeading;
            
            // Record maneuver in history
            recordManeuver(false, afterHeading, maneuverAngle);
            
            log("Gybe recorded: #" + mGybeCount + ", angle: " + maneuverAngle + "°");
        }
    }
    
    // Record maneuver in history
    function recordManeuver(isTack, heading, angle) {
        // Create maneuver record
        var maneuver = {
            "isTack" => isTack,
            "heading" => heading,
            "angle" => angle,
            "time" => Time.now().value(),
            "timestamp" => System.getTimer(),
            "lapNumber" => mParent.getLapTracker().getCurrentLap()
        };
        
        // Calculate index in history array
        var index = isTack ? (mTackCount - 1) : (mGybeCount - 1);
        
        // Store in history if index is valid
        if (index >= 0 && index < mParent.MAX_MANEUVERS) {
            mManeuverHistory[index] = maneuver;
            
            // Add to lap-specific maneuvers if lap tracking is active
            mParent.getLapTracker().recordManeuverInLap(maneuver);
            
            // Update statistics
            updateManeuverStats();
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
        for (var i = 0; i < mParent.MAX_MANEUVERS; i++) {
            if (mManeuverHistory[i] != null) {
                var maneuver = mManeuverHistory[i];
                
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
    }
    
    // Get recommended wind direction based on maneuvers
    function getRecommendedWindDirection() {
        var shouldUpdate = false;
        var newWindDirection = mParent.getWindDirection();
        
        // Check if we have two consecutive tacks
        if (mTackCount >= 2) {
            var heading1 = mLastTackHeadings[0];
            var heading2 = mLastTackHeadings[1];
            
            if (heading1 != 0 && heading2 != 0) {
                // Calculate bisector angle between tack headings
                var bisector = mParent.getAngleCalculator().calculateBisectorAngle(heading1, heading2);
                newWindDirection = bisector;
                
                log("Auto wind calculation from tacks:");
                log("- Heading 1: " + heading1 + "°");
                log("- Heading 2: " + heading2 + "°");
                log("- Calculated bisector: " + bisector + "°");
                
                // Check if significantly different (> 120°)
                var windDiff = mParent.getAngleCalculator().angleAbsDifference(newWindDirection, mParent.getWindDirection());
                if (windDiff > 120) {
                    // Adjust by 180° to get correct orientation
                    newWindDirection = mParent.getAngleCalculator().normalizeAngle(newWindDirection + 180);
                    log("- Wind direction adjusted by 180° due to large difference");
                }
                
                shouldUpdate = true;
            }
        }
        // Or check if we have two consecutive gybes
        else if (mGybeCount >= 2) {
            var heading1 = mLastGybeHeadings[0];
            var heading2 = mLastGybeHeadings[1];
            
            if (heading1 != 0 && heading2 != 0) {
                // Calculate bisector, then add 180° for downwind
                var bisector = mParent.getAngleCalculator().calculateBisectorAngle(heading1, heading2);
                newWindDirection = mParent.getAngleCalculator().normalizeAngle(bisector + 180);
                
                log("Auto wind calculation from gybes:");
                log("- Heading 1: " + heading1 + "°");
                log("- Heading 2: " + heading2 + "°");
                log("- Calculated bisector: " + bisector + "°");
                log("- Wind direction (bisector + 180°): " + newWindDirection + "°");
                
                // Check if significantly different (> 120°)
                var windDiff = mParent.getAngleCalculator().angleAbsDifference(newWindDirection, mParent.getWindDirection());
                if (windDiff > 120) {
                    // Adjust by 180° to get correct orientation
                    newWindDirection = mParent.getAngleCalculator().normalizeAngle(newWindDirection + 180);
                    log("- Wind direction adjusted by 180° due to large difference");
                }
                
                shouldUpdate = true;
            }
        }
        
        return {
            "updateNeeded" => shouldUpdate,
            "direction" => newWindDirection
        };
    }
    
    // Accessors
    function getTackCount() {
        return mTackCount;
    }
    
    function getGybeCount() {
        return mGybeCount;
    }
    
    function getLastTackAngle() {
        return mLastTackAngle;
    }
    
    function getLastGybeAngle() {
        return mLastGybeAngle;
    }
    
    function getManeuverStats() {
        return mManeuverStats;
    }
    
    // Get data for parent
    function getData() {
        return {
            "tackCount" => mTackCount,
            "gybeCount" => mGybeCount,
            "lastTackAngle" => mLastTackAngle,
            "lastGybeAngle" => mLastGybeAngle,
            "maneuverStats" => mManeuverStats,
            "maneuverHistory" => mManeuverHistory
        };
    }
}