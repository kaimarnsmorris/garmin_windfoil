// VMGCalculator.mc - Handles VMG calculations
using Toybox.Math;
using Toybox.System;

class VMGCalculator {
    // Constants
    private const VMG_SMOOTHING_FACTOR = 0.1;  // Smoothing factor for VMG

    // Properties
    private var mParent;              // Reference to WindTracker parent
    private var mCurrentVMG;          // Current velocity made good (knots)
    
    // Initialize
    function initialize(parent) {
        mParent = parent;
        reset();
    }
    
    // Reset calculator
    function reset() {
        mCurrentVMG = 0.0;
        log("VMGCalculator reset");
    }
    
    // Calculate VMG with smoothing
    function calculateVMG(heading, speed, isUpwind, windAngleLessCOG) {
        if (speed <= 0) {
            mCurrentVMG = 0.0;
            return 0.0;
        }
        
        // Get absolute wind angle for VMG calculation
        var absWindAngle = (windAngleLessCOG < 0) ? -windAngleLessCOG : windAngleLessCOG;
        
        // Calculate raw VMG
        var windAngleRad;
        var rawVMG;
        
        if (isUpwind) {
            // Upwind calculation
            windAngleRad = Math.toRadians(absWindAngle);
            rawVMG = speed * Math.cos(windAngleRad);
        } else {
            // Downwind calculation
            windAngleRad = Math.toRadians(180 - absWindAngle);
            rawVMG = speed * Math.cos(windAngleRad);
        }
        
        // Ensure VMG is positive (speed TO wind or AWAY from wind)
        if (rawVMG < 0) {
            rawVMG = -rawVMG;
        }
        
        // Apply smoothing using EMA
        if (mCurrentVMG > 0) {
            mCurrentVMG = (mCurrentVMG * (1.0 - VMG_SMOOTHING_FACTOR)) + (rawVMG * VMG_SMOOTHING_FACTOR);
        } else {
            mCurrentVMG = rawVMG;
        }
        
    log("VMG Calculation - Wind: " + mParent.getWindDirection() + 
        "°, COG: " + heading + 
        "°, WindAngle: " + windAngleLessCOG + 
        "°, VMG: " + mCurrentVMG.format("%.2f") + " kts");
            
        return mCurrentVMG;
    }
    
    // Get current VMG value
    function getCurrentVMG() {
        return mCurrentVMG;
    }
    
    // Get VMG data for parent
    function getData() {
        return {
            "currentVMG" => mCurrentVMG
        };
    }
}