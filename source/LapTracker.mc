// LapTracker.mc - Tracks lap-specific data
using Toybox.System;
using Toybox.Math;

class LapTracker {
    // Properties
    private var mParent;                  // Reference to WindTracker parent
    private var mCurrentLapNumber;        // Current lap number
    private var mLapManeuvers;            // Dictionary of maneuvers by lap
    private var mLapStats;                // Dictionary of stats by lap
    private var mLastLapStartTime;        // Timestamp of lap start
    private var mLapStartPositions;       // Start positions by lap
    private var mLapStartTimestamps;      // Start times by lap
    private var mLapDistances;            // Distances by lap

    // Foiling statistics
    private var mLapFoilingPoints;        // Points spent foiling by lap
    private var mLapTotalPoints;          // Total points by lap

    // VMG statistics
    private var mLapVMGUpTotal;           // Total upwind VMG by lap
    private var mLapVMGDownTotal;         // Total downwind VMG by lap
    private var mLapUpwindPoints;         // Upwind data points by lap
    private var mLapDownwindPoints;       // Downwind data points by lap
    
    // Initialize
    function initialize(parent) {
        mParent = parent;
        reset();
    }
    
    // Reset lap data
    function reset() {
        mCurrentLapNumber = 0;
        mLapManeuvers = {};
        mLapStats = {};
        mLastLapStartTime = System.getTimer();
        mLapStartPositions = {};
        mLapStartTimestamps = {};
        mLapDistances = {};
        
        // Reset foiling statistics
        mLapFoilingPoints = {};
        mLapTotalPoints = {};
        
        // Reset VMG statistics
        mLapVMGUpTotal = {};
        mLapVMGDownTotal = {};
        mLapUpwindPoints = {};
        mLapDownwindPoints = {};
        
        log("LapTracker reset");
    }
    
    // Mark the start of a new lap
    function onLapMarked(position) {
        // Increment lap counter
        mCurrentLapNumber++;
        
        // Store lap start position
        if (position != null) {
            mLapStartPositions[mCurrentLapNumber] = position;
            log("Stored start position for lap " + mCurrentLapNumber);
        }
        
        // Set timestamp for the new lap
        var currentTime = System.getTimer();
        mLastLapStartTime = currentTime;
        mLapStartTimestamps[mCurrentLapNumber] = currentTime;
        
        // Initialize lap distance
        mLapDistances[mCurrentLapNumber] = 0.0;
        
        // Initialize foiling counters
        mLapFoilingPoints[mCurrentLapNumber] = 0;
        mLapTotalPoints[mCurrentLapNumber] = 0;
        
        // Initialize VMG averages
        mLapVMGUpTotal[mCurrentLapNumber] = 0.0;
        mLapVMGDownTotal[mCurrentLapNumber] = 0.0;
        mLapUpwindPoints[mCurrentLapNumber] = 0;
        mLapDownwindPoints[mCurrentLapNumber] = 0;
        
        // Initialize maneuver tracking for this lap
        mLapManeuvers[mCurrentLapNumber] = {
            "tacks" => [],
            "gybes" => []
        };
        
        // Initialize statistics for this lap
        mLapStats[mCurrentLapNumber] = {
            "tackCount" => 0,
            "gybeCount" => 0,
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "maxTackAngle" => 0,
            "maxGybeAngle" => 0,
            "lapVMG" => 0.0,
            "pctOnFoil" => 0.0,
            "avgVMGUp" => 0.0,
            "avgVMGDown" => 0.0
        };
        
        log("New lap marked: " + mCurrentLapNumber);
        
        return mCurrentLapNumber;
    }
    
    // Process position data for lap-specific calculations
    function processData(info, speed, isUpwind, currentTime) {
        // Skip if not tracking a lap yet
        if (mCurrentLapNumber <= 0) {
            return;
        }
        
        // Track foiling status
        var foilingThreshold = 7.0; // Default threshold in knots
        
        // Try to get from settings
        try {
            var app = Application.getApp();
            if (app != null && app has :mModel && app.mModel != null) {
                var data = app.mModel.getData();
                if (data != null && data.hasKey("settings")) {
                    var settings = data["settings"];
                    if (settings != null && settings.hasKey("foilingThreshold")) {
                        foilingThreshold = settings["foilingThreshold"];
                    }
                }
            }
        } catch (e) {
            log("Error getting foiling threshold: " + e.getErrorMessage());
        }
        
        // Check if currently foiling
        var isOnFoil = (speed >= foilingThreshold);
        
        // Update foiling percentage for current lap
        updateLapFoilingPercentage(isOnFoil);
        
        // Update lap VMG averages
        updateLapVMGAverages(speed, isUpwind);
        
        // Update lap VMG calculation
        updateLapVMG(info);
    }
    
    // Update lap VMG calculations
    function updateLapVMG(posInfo) {
        if (mCurrentLapNumber <= 0 || posInfo == null) {
            return;
        }
        
        // Store position as start if none exists
        if (!mLapStartPositions.hasKey(mCurrentLapNumber)) {
            mLapStartPositions[mCurrentLapNumber] = posInfo;
            return;
        }
        
        // Get lap start position
        var startPos = mLapStartPositions[mCurrentLapNumber];
        
        // Calculate distance and bearing
        var distance = 0.0;
        var bearing = 0.0;
        
        // Use Garmin's Position.distanceToPosition if available
        if (posInfo has :distanceToPosition && startPos has :toRadians) {
            try {
                var distanceResult = Position.distanceToPosition(posInfo, startPos);
                if (distanceResult != null) {
                    distance = distanceResult[0];  // Distance in meters
                    bearing = distanceResult[1];   // Bearing in radians
                    
                    // Convert bearing to degrees if needed
                    if (bearing < 2 * Math.PI) {
                        bearing = Math.toDegrees(bearing);
                    }
                }
            } catch(e) {
                log("Error calculating distance: " + e.getErrorMessage());
                
                // Fallback to simplified calculation
                if (posInfo has :position && startPos has :position) {
                    // Basic distance calculation
                    var lat1 = startPos.position[0];
                    var lon1 = startPos.position[1];
                    var lat2 = posInfo.position[0];
                    var lon2 = posInfo.position[1];
                    
                    // Approximate distance using Pythagorean theorem
                    var latDiff = lat2 - lat1;
                    var lonDiff = lon2 - lon1;
                    
                    // Converting to approximate meters
                    var latMeters = latDiff * 111320; // 1 degree lat is ~111.32 km
                    var lonMeters = lonDiff * 111320 * Math.cos(Math.toRadians((lat1 + lat2) / 2));
                    
                    distance = Math.sqrt(latMeters * latMeters + lonMeters * lonMeters);
                    
                    // Calculate bearing
                    bearing = Math.toDegrees(Math.atan2(lonDiff, latDiff));
                    if (bearing < 0) {
                        bearing += 360;
                    }
                }
            }
        }
        
        // Store distance for other calculations
        if (distance > 0) {
            mLapDistances[mCurrentLapNumber] = distance;
        }
        
        // Get current timestamp
        var currentTime = System.getTimer();
        
        // Calculate time elapsed since lap start (in hours)
        var lapStartTime = mLapStartTimestamps[mCurrentLapNumber];
        var elapsedTimeHours = (currentTime - lapStartTime) / (1000.0 * 60.0 * 60.0);
        
        // Skip VMG calculation if elapsed time is too small
        if (elapsedTimeHours < 0.001) {
            return;
        }
        
        // Calculate projection onto wind direction
        var windDirRadians = Math.toRadians(mParent.getWindDirection());
        var bearingRadians = Math.toRadians(bearing);
        
        // Component of travel in direction of wind
        var distanceToWind = distance * Math.cos(bearingRadians - windDirRadians);
        
        // If going upwind, we want to go against the wind, so negate
        if (mParent.getAngleCalculator().isUpwind()) {
            distanceToWind = -distanceToWind;
        }
        
        // Convert from meters to nautical miles (1 nm = 1852 meters)
        var distanceNM = distanceToWind / 1852.0;
        
        // Calculate VMG in knots (nautical miles per hour)
        var lapVMG = distanceNM / elapsedTimeHours;
        
        // Update lap stats with this VMG
        if (mLapStats.hasKey(mCurrentLapNumber)) {
            mLapStats[mCurrentLapNumber]["lapVMG"] = lapVMG;
        }
    }
    
    // Update foiling percentage for current lap
    function updateLapFoilingPercentage(isOnFoil) {
        if (mCurrentLapNumber <= 0) {
            return;
        }
        
        // Increment total points for this lap
        if (!mLapTotalPoints.hasKey(mCurrentLapNumber)) {
            mLapTotalPoints[mCurrentLapNumber] = 0;
        }
        mLapTotalPoints[mCurrentLapNumber]++;
        
        // Increment foiling points if on foil
        if (isOnFoil) {
            if (!mLapFoilingPoints.hasKey(mCurrentLapNumber)) {
                mLapFoilingPoints[mCurrentLapNumber] = 0;
            }
            mLapFoilingPoints[mCurrentLapNumber]++;
        }
        
        // Calculate percentage for this lap
        if (mLapTotalPoints[mCurrentLapNumber] > 0) {
            var pctOnFoil = (mLapFoilingPoints[mCurrentLapNumber] * 100.0) / 
                            mLapTotalPoints[mCurrentLapNumber];
            
            // Update lap stats
            if (mLapStats.hasKey(mCurrentLapNumber)) {
                mLapStats[mCurrentLapNumber]["pctOnFoil"] = pctOnFoil;
            }
        }
    }
    
    // Update lap VMG averages
    function updateLapVMGAverages(speed, isUpwind) {
        if (mCurrentLapNumber <= 0) {
            return;
        }
        
        // Calculate VMG for current speed and wind angle
        var absWindAngle = mParent.getAngleCalculator().getAbsWindAngle();
        var windAngleRad;
        var lapVMG;
        
        if (isUpwind) {
            // Upwind calculation
            windAngleRad = Math.toRadians(absWindAngle);
            lapVMG = speed * Math.cos(windAngleRad);
            
            // Ensure positive (moving toward wind)
            if (lapVMG < 0) {
                lapVMG = -lapVMG;
            }
            
            // Add to upwind totals
            if (!mLapVMGUpTotal.hasKey(mCurrentLapNumber)) {
                mLapVMGUpTotal[mCurrentLapNumber] = 0.0;
                mLapUpwindPoints[mCurrentLapNumber] = 0;
            }
            
            mLapVMGUpTotal[mCurrentLapNumber] += lapVMG;
            mLapUpwindPoints[mCurrentLapNumber]++;
            
            // Calculate average upwind VMG
            if (mLapUpwindPoints[mCurrentLapNumber] > 0) {
                var avgVMGUp = mLapVMGUpTotal[mCurrentLapNumber] / 
                              mLapUpwindPoints[mCurrentLapNumber];
                
                // Update lap stats
                if (mLapStats.hasKey(mCurrentLapNumber)) {
                    mLapStats[mCurrentLapNumber]["avgVMGUp"] = avgVMGUp;
                }
            }
        } else {
            // Downwind calculation
            windAngleRad = Math.toRadians(180 - absWindAngle);
            lapVMG = speed * Math.cos(windAngleRad);
            
            // Ensure positive (moving away from wind)
            if (lapVMG < 0) {
                lapVMG = -lapVMG;
            }
            
            // Add to downwind totals
            if (!mLapVMGDownTotal.hasKey(mCurrentLapNumber)) {
                mLapVMGDownTotal[mCurrentLapNumber] = 0.0;
                mLapDownwindPoints[mCurrentLapNumber] = 0;
            }
            
            mLapVMGDownTotal[mCurrentLapNumber] += lapVMG;
            mLapDownwindPoints[mCurrentLapNumber]++;
            
            // Calculate average downwind VMG
            if (mLapDownwindPoints[mCurrentLapNumber] > 0) {
                var avgVMGDown = mLapVMGDownTotal[mCurrentLapNumber] / 
                                mLapDownwindPoints[mCurrentLapNumber];
                
                // Update lap stats
                if (mLapStats.hasKey(mCurrentLapNumber)) {
                    mLapStats[mCurrentLapNumber]["avgVMGDown"] = avgVMGDown;
                }
            }
        }
    }
    
    // Record a maneuver in the current lap
    function recordManeuverInLap(maneuver) {
        if (mCurrentLapNumber <= 0 || !mLapManeuvers.hasKey(mCurrentLapNumber)) {
            return;
        }
        
        var isTack = maneuver["isTack"];
        
        // Add to lap-specific collections
        if (isTack) {
            mLapManeuvers[mCurrentLapNumber]["tacks"].add(maneuver);
        } else {
            mLapManeuvers[mCurrentLapNumber]["gybes"].add(maneuver);
        }
        
        // Update lap-specific statistics
        updateLapManeuverStats(mCurrentLapNumber);
    }
    
    // Update lap-specific maneuver statistics
    function updateLapManeuverStats(lapNumber) {
        if (!mLapManeuvers.hasKey(lapNumber) || !mLapStats.hasKey(lapNumber)) {
            return;
        }
        
        var lapTacks = mLapManeuvers[lapNumber]["tacks"];
        var lapGybes = mLapManeuvers[lapNumber]["gybes"];
        
        var tackCount = lapTacks.size();
        var gybeCount = lapGybes.size();
        var tackSum = 0;
        var gybeSum = 0;
        var maxTack = 0;
        var maxGybe = 0;
        
        // Calculate tack statistics
        for (var i = 0; i < tackCount; i++) {
            var angle = lapTacks[i]["angle"];
            tackSum += angle;
            if (angle > maxTack) {
                maxTack = angle;
            }
        }
        
        // Calculate gybe statistics
        for (var i = 0; i < gybeCount; i++) {
            var angle = lapGybes[i]["angle"];
            gybeSum += angle;
            if (angle > maxGybe) {
                maxGybe = angle;
            }
        }
        
        // Calculate averages
        var avgTack = (tackCount > 0) ? tackSum / tackCount : 0;
        var avgGybe = (gybeCount > 0) ? gybeSum / gybeCount : 0;
        
        // Update lap stats with existing fields preserved
        var existingStats = mLapStats[lapNumber];
        mLapStats[lapNumber] = {
            "tackCount" => tackCount,
            "gybeCount" => gybeCount,
            "avgTackAngle" => avgTack,
            "avgGybeAngle" => avgGybe,
            "maxTackAngle" => maxTack,
            "maxGybeAngle" => maxGybe,
            "lapVMG" => existingStats.hasKey("lapVMG") ? existingStats["lapVMG"] : 0.0,
            "pctOnFoil" => existingStats.hasKey("pctOnFoil") ? existingStats["pctOnFoil"] : 0.0,
            "avgVMGUp" => existingStats.hasKey("avgVMGUp") ? existingStats["avgVMGUp"] : 0.0,
            "avgVMGDown" => existingStats.hasKey("avgVMGDown") ? existingStats["avgVMGDown"] : 0.0
        };
    }
    
    // Get time since last tack in current lap
    function getTimeSinceLastTack() {
        if (mCurrentLapNumber <= 0 || !mLapManeuvers.hasKey(mCurrentLapNumber)) {
            return 0.0;
        }
        
        var tackArray = mLapManeuvers[mCurrentLapNumber]["tacks"];
        if (tackArray == null || tackArray.size() == 0) {
            // If no tacks in lap, return time since lap start
            var currentTime = System.getTimer();
            return (currentTime - mLastLapStartTime) / 1000.0;
        }
        
        // Get timestamp of last tack
        var lastTackTimestamp = tackArray[tackArray.size() - 1]["timestamp"];
        var currentTime = System.getTimer();
        
        // Return seconds since last tack
        return (currentTime - lastTackTimestamp) / 1000.0;
    }
    
    // Get data for lap markers
    function getLapData() {
        // Create a data structure for lap fields with default values
        var lapData = {
            "vmgUp" => 0.0,
            "vmgDown" => 0.0,
            "tackSec" => 0.0,
            "tackMtr" => 0.0,
            "avgTackAngle" => 0,
            "lapVMG" => 0.0,
            "pctOnFoil" => 0.0
        };
        
        log("Preparing lap data for current lap: " + mCurrentLapNumber);
        
        // Use lap-specific values if available
        if (mCurrentLapNumber > 0 && mLapStats.hasKey(mCurrentLapNumber)) {
            var lapStats = mLapStats[mCurrentLapNumber];
            log("Found lap stats for lap " + mCurrentLapNumber);
            
            // Get lap-specific VMG values
            if (lapStats.hasKey("avgVMGUp")) {
                lapData["vmgUp"] = lapStats["avgVMGUp"];
                log("- Using lap-specific VMG Up: " + lapData["vmgUp"]);
            }
            
            if (lapStats.hasKey("avgVMGDown")) {
                lapData["vmgDown"] = lapStats["avgVMGDown"];
                log("- Using lap-specific VMG Down: " + lapData["vmgDown"]);
            }
            
            // Get lap-specific percent on foil
            if (lapStats.hasKey("pctOnFoil")) {
                lapData["pctOnFoil"] = lapStats["pctOnFoil"];
                log("- Using lap-specific pctOnFoil: " + lapData["pctOnFoil"]);
            } else if (mLapFoilingPoints.hasKey(mCurrentLapNumber) && mLapTotalPoints.hasKey(mCurrentLapNumber)) {
                // Calculate directly if not in stats
                if (mLapTotalPoints[mCurrentLapNumber] > 0) {
                    lapData["pctOnFoil"] = (mLapFoilingPoints[mCurrentLapNumber] * 100.0) / mLapTotalPoints[mCurrentLapNumber];
                    log("- Calculated pctOnFoil: " + lapData["pctOnFoil"]);
                }
            }
            
            // Get lap-specific tack angle
            if (lapStats.hasKey("avgTackAngle")) {
                lapData["avgTackAngle"] = lapStats["avgTackAngle"];
                log("- Using lap-specific avgTackAngle: " + lapData["avgTackAngle"]);
            }
            
            // Get lap-specific VMG
            if (lapStats.hasKey("lapVMG")) {
                lapData["lapVMG"] = lapStats["lapVMG"];
                log("- Using lap-specific lapVMG: " + lapData["lapVMG"]);
            }
            
            // Calculate time since last tack
            lapData["tackSec"] = getTimeSinceLastTack();
            log("- Time since last tack: " + lapData["tackSec"] + "s");
        } else {
            log("No lap-specific data found for lap " + mCurrentLapNumber + ", using fallback values");
            
            // Fall back to current VMG values based on point of sail
            var currentVMG = mParent.getVMGCalculator().getCurrentVMG();
            var isUpwind = mParent.getAngleCalculator().isUpwind();
            
            if (isUpwind) {
                lapData["vmgUp"] = currentVMG;
                lapData["vmgDown"] = 0.0;
                log("- Fallback VMG Up (current): " + currentVMG);
            } else {
                lapData["vmgUp"] = 0.0;
                lapData["vmgDown"] = currentVMG;
                log("- Fallback VMG Down (current): " + currentVMG);
            }
            
            // Fall back to model percent on foil
            try {
                var app = Application.getApp();
                if (app != null && app has :mModel && app.mModel != null) {
                    var data = app.mModel.getData();
                    if (data != null && data.hasKey("percentOnFoil")) {
                        lapData["pctOnFoil"] = data["percentOnFoil"];
                        log("- Fallback pctOnFoil (from model): " + lapData["pctOnFoil"]);
                    }
                }
            } catch (e) {
                log("Error getting fallback pctOnFoil: " + e.getErrorMessage());
            }
            
            // Fall back to overall maneuver stats for tack angle
            var maneuverStats = mParent.getManeuverDetector().getManeuverStats();
            if (maneuverStats != null && maneuverStats.hasKey("avgTackAngle")) {
                lapData["avgTackAngle"] = maneuverStats["avgTackAngle"];
                log("- Fallback avgTackAngle (overall): " + lapData["avgTackAngle"]);
            }
        }
        
        // Include the distance traveled in this lap if available
        if (mCurrentLapNumber > 0 && mLapDistances.hasKey(mCurrentLapNumber)) {
            lapData["tackMtr"] = mLapDistances[mCurrentLapNumber];
            log("- Distance for this lap: " + lapData["tackMtr"] + "m");
        }
        
        // Make sure values are sensible - round to 1 decimal place
        try {
            // Round floating point values to 1 decimal place
            lapData["vmgUp"] = Math.round(lapData["vmgUp"] * 10) / 10.0;
            lapData["vmgDown"] = Math.round(lapData["vmgDown"] * 10) / 10.0;
            lapData["tackSec"] = Math.round(lapData["tackSec"] * 10) / 10.0;
            lapData["tackMtr"] = Math.round(lapData["tackMtr"] * 10) / 10.0;
            lapData["lapVMG"] = Math.round(lapData["lapVMG"] * 10) / 10.0;
            lapData["pctOnFoil"] = Math.round(lapData["pctOnFoil"]);
            lapData["avgTackAngle"] = Math.round(lapData["avgTackAngle"]);
            
            log("Rounded all lap data values");
        } catch (e) {
            log("Error rounding lap data values: " + e.getErrorMessage());
        }
        
        return lapData;
    }
    
    // Accessors
    function getCurrentLap() {
        return mCurrentLapNumber;
    }
    
    function getLapStats(lapNumber) {
        if (lapNumber > 0 && mLapStats.hasKey(lapNumber)) {
            return mLapStats[lapNumber];
        }
        return null;
    }
    
    function getLapManeuvers(lapNumber) {
        if (lapNumber > 0 && mLapManeuvers.hasKey(lapNumber)) {
            return mLapManeuvers[lapNumber];
        }
        return null;
    }
}