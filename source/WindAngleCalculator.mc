// WindAngleCalculator.mc - Handles angle calculations for WindTracker
using Toybox.Math;
using Toybox.System;

class WindAngleCalculator {
    // Constants
    private const COG_SMOOTHING_FACTOR = 0.15;     // Smoothing factor for heading
    private const HEADING_HISTORY_SIZE = 60;       // Store 60 seconds of heading history

    // Properties
    private var mParent;                     // Reference to WindTracker parent
    private var mSmoothedCOG;                // Smoothed Course Over Ground
    private var mPrevSmoothedCOG;            // Previous smoothed COG
    private var mWindAngleLessCOG;           // Wind angle relative to COG (-180 to 180)
    private var mLastWindAngleLessCOG;       // Previous wind angle for maneuver detection
    private var mIsStbdTack;                 // True if on starboard tack (wind from starboard)
    private var mIsUpwind;                   // True if sailing upwind (wind from ahead)
    private var mHeadingBuffer;              // Buffer for recent headings
    private var mBufferIndex;                // Current index in heading buffer
    private var mHeadingHistory;             // Array to store heading history with timestamps
    private var mHeadingHistoryIndex;        // Current index in heading history
    private var mHasPreviousData;            // Flag to indicate we have previous data
    
    // Initialize
    function initialize(parent) {
        mParent = parent;
        reset();
    }
    
    // Reset data
    function reset() {
        mSmoothedCOG = 0;
        mPrevSmoothedCOG = 0;
        mWindAngleLessCOG = 0;
        mLastWindAngleLessCOG = 0;
        mIsStbdTack = false;
        mIsUpwind = false;
        mHasPreviousData = false;
        
        // Initialize heading buffer
        mHeadingBuffer = new [mParent.HEADING_BUFFER_SIZE];
        for (var i = 0; i < mParent.HEADING_BUFFER_SIZE; i++) {
            mHeadingBuffer[i] = 0;
        }
        mBufferIndex = 0;
        
        // Initialize heading history
        mHeadingHistory = new [HEADING_HISTORY_SIZE];
        for (var i = 0; i < HEADING_HISTORY_SIZE; i++) {
            mHeadingHistory[i] = {
                "heading" => 0,
                "timestamp" => 0,
                "valid" => false
            };
        }
        mHeadingHistoryIndex = 0;
        
        log("WindAngleCalculator reset");
    }
    
    // Process new heading data
    function processHeading(heading, timestamp) {
        // Store previous values for comparison
        mLastWindAngleLessCOG = mWindAngleLessCOG;
        
        // Normalize heading to 0-360
        heading = normalizeAngle(heading);
        
        // Apply smoothing
        var smoothedHeading = applyCOGSmoothing(heading);
        
        // Store the heading in buffers
        storeHeadingInBuffer(smoothedHeading);
        storeHeadingHistory(smoothedHeading, timestamp);
        
        // Get wind direction using parent's accessor method
        var windDirection = mParent.getWindDirection();
        
        // Recalculate wind angle
        calculateWindAngleLessCOG(smoothedHeading, windDirection);
        
        // Initialize tack and point of sail if this is first valid data
        if (!mHasPreviousData) {
            initializeTackAndPointOfSail();
            mHasPreviousData = true;
        } else {
            // Update point of sail based on new angle
            determinePointOfSail();
        }
        
        return smoothedHeading;
    }
    
    // Store heading in buffer
    function storeHeadingInBuffer(heading) {
        mHeadingBuffer[mBufferIndex] = heading;
        mBufferIndex = (mBufferIndex + 1) % mParent.HEADING_BUFFER_SIZE;
    }
    
    // Store heading in history with timestamp
    function storeHeadingHistory(heading, timestamp) {
        mHeadingHistory[mHeadingHistoryIndex] = {
            "heading" => heading,
            "timestamp" => timestamp,
            "valid" => true
        };
        
        mHeadingHistoryIndex = (mHeadingHistoryIndex + 1) % HEADING_HISTORY_SIZE;
    }
    
    // Apply smoothing to COG
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
    
    // Calculate wind angle less COG
    function calculateWindAngleLessCOG(heading, windDirection) {
        // If windDirection parameter is not provided, get it from parent
        if (windDirection == null) {
            windDirection = mParent.getWindDirection();
        }
        
        // Wind angle less COG
        var windAngle = windDirection - heading;
        
        // Normalize to -180 to 180
        if (windAngle > 180) {
            windAngle -= 360;
        } else if (windAngle <= -180) {
            windAngle += 360;
        }
        
        mWindAngleLessCOG = windAngle;
        return windAngle;
    }
    
    // Initialize tack and point of sail
    function initializeTackAndPointOfSail() {
        // Positive wind angle = starboard tack, negative = port tack
        mIsStbdTack = (mWindAngleLessCOG >= 0);
        
        // Upwind if wind angle is between -90 and 90 degrees
        mIsUpwind = (mWindAngleLessCOG > -90 && mWindAngleLessCOG < 90);
        
        log("Initialized tack: " + (mIsStbdTack ? "Starboard" : "Port") + 
            ", Point of sail: " + (mIsUpwind ? "Upwind" : "Downwind") +
            ", WindAngleLessCOG: " + mWindAngleLessCOG);
    }
    
    // Determine current point of sail
    function determinePointOfSail() {
        // Upwind if wind angle is between -90 and 90 degrees
        var newUpwind = (mWindAngleLessCOG > -90 && mWindAngleLessCOG < 90);
        
        // Log change if point of sail changed
        if (mIsUpwind != newUpwind) {
            log("Point of sail changed from " + (mIsUpwind ? "Upwind" : "Downwind") + 
                " to " + (newUpwind ? "Upwind" : "Downwind") + 
                " (WindAngle: " + mWindAngleLessCOG + "°)");
            mIsUpwind = newUpwind;
        }
    }
    
    // Calculate average heading over a time period
    function calculateAverageHeading(startTime, endTime) {
        var sumX = 0.0;
        var sumY = 0.0;
        var count = 0;
        
        // Loop through heading history
        for (var i = 0; i < HEADING_HISTORY_SIZE; i++) {
            var entry = mHeadingHistory[i];
            
            // Skip invalid entries
            if (!entry["valid"]) {
                continue;
            }
            
            var timestamp = entry["timestamp"];
            var heading = entry["heading"];
            
            // Check if entry is within time period
            if (timestamp >= startTime && timestamp <= endTime) {
                // Convert heading to radians
                var rad = Math.toRadians(heading);
                
                // Add to vector components
                sumX += Math.cos(rad);
                sumY += Math.sin(rad);
                count++;
            }
        }
        
        // If no valid entries, return null
        if (count == 0) {
            log("No valid heading entries found for time period: " + 
                (startTime/1000) + "s to " + (endTime/1000) + "s");
            return null;
        }
        
        // Calculate average vector
        var avgX = sumX / count;
        var avgY = sumY / count;
        
        // Calculate average heading in degrees
        var avgHeading = Math.toDegrees(Math.atan2(avgY, avgX));
        
        // Normalize to 0-360
        return normalizeAngle(avgHeading);
    }
    
    // Helper functions
    function normalizeAngle(angle) {
        while (angle < 0) {
            angle += 360;
        }
        while (angle >= 360) {
            angle -= 360;
        }
        return angle;
    }
    
    function angleAbsDifference(angle1, angle2) {
        // Normalize angles
        angle1 = normalizeAngle(angle1);
        angle2 = normalizeAngle(angle2);
        
        // Calculate difference
        var diff = angle1 - angle2;
        if (diff < 0) {
            diff = -diff;  // Absolute value
        }
        
        // Take the smaller angle
        if (diff > 180) {
            diff = 360 - diff;
        }
        
        return diff;
    }
    
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
        
        // Check for zero vector
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
    
    // Recalculate with new wind direction
    function recalculateWithNewWindDirection(windDirection) {
        // Recalculate wind angle with current smoothed heading
        calculateWindAngleLessCOG(mSmoothedCOG, windDirection);
        
        // Update tack and point of sail
        determinePointOfSail();
    }
    
    // Accessors
    function getSmoothedCOG() {
        return mSmoothedCOG;
    }
    
    function getWindAngleLessCOG() {
        return mWindAngleLessCOG;
    }
    
    function getLastWindAngleLessCOG() {
        return mLastWindAngleLessCOG;
    }
    
    function isStarboardTack() {
        return mIsStbdTack;
    }
    
    function setStarboardTack(isStbd) {
        mIsStbdTack = isStbd;
    }
    
    function isUpwind() {
        return mIsUpwind;
    }
    
    function hasPreviousData() {
        return mHasPreviousData;
    }
    
    function getAbsWindAngle() {
        var absAngle = mWindAngleLessCOG;
        if (absAngle < 0) {
            absAngle = -absAngle;
        }
        return absAngle;
    }
    
    // Get data for parent
    function getData() {
        var tackStr = mIsStbdTack ? "Starboard" : "Port";
        var pointOfSailStr = mIsUpwind ? "Upwind" : "Downwind";
        var tackDisplayStr = mIsStbdTack ? "Stb" : "Prt";
        var tackColorId = mIsStbdTack ? 1 : 2;  // 1 = green, 2 = red
        
        return {
            "windAngleLessCOG" => mWindAngleLessCOG,
            "currentTack" => tackStr,
            "currentPointOfSail" => pointOfSailStr,
            "tackDisplayText" => tackDisplayStr,
            "tackColorId" => tackColorId
        };
    }
}