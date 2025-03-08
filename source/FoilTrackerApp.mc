using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Position;
using Toybox.Timer;
using Toybox.Lang;
using Toybox.FitContributor;

// Main Application class
class FoilTrackerApp extends Application.AppBase {
    // Initialize class variables
    private var mView;
    private var mModel;
    private var mSession;
    private var mPositionEnabled;
    private var mTimer;
    private var mTimerRunning;
    private var mWindTracker;  // Wind tracker
    
    // FitContributor fields for Session
    private var mWorkoutNameField;
    private var mWindStrengthField;
    private var mWindDirectionField;
    
    // FitContributor fields for Lap
    private var mLapPctOnFoilField;
    private var mLapVMGUpField;
    private var mLapVMGDownField;
    private var mLapTackSecField;
    private var mLapTackMtrField;
    private var mLapWindDirectionField;
    private var mLapWindStrengthField;
    private var mLapAvgTackAngleField;

    // Initialize the application
    function initialize() {
        AppBase.initialize();
        mModel = null;
        mSession = null;
        mPositionEnabled = false;
        mTimer = null;
        mTimerRunning = false;
        mWindTracker = new WindTracker();  // Initialize wind tracker
        
        // Initialize FitContributor fields
        mWorkoutNameField = null;
        mWindStrengthField = null;
        mWindDirectionField = null;
        
        // Initialize Lap fields
        mLapPctOnFoilField = null;
        mLapVMGUpField = null;
        mLapVMGDownField = null;
        mLapTackSecField = null;
        mLapTackMtrField = null;
        mLapWindDirectionField = null;
        mLapWindStrengthField = null;
        mLapAvgTackAngleField = null;
    }

    // onStart() is called when the application is starting
    function onStart(state) {
        System.println("App starting");
        // Initialize the app model if not already done
        if (mModel == null) {
            mModel = new FoilTrackerModel();
        }
        System.println("Model initialized");
        
        // Enable position tracking
        try {
            // Define a callback that matches the expected signature
            mPositionEnabled = true;
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, new Method(self, :onPositionCallback));
            System.println("Position tracking enabled");
        } catch (e) {
            mPositionEnabled = false;
            System.println("Error enabling position tracking: " + e.getErrorMessage());
        }
        
        // Note: We'll start the activity session after wind strength is selected
        // in the StartupWindStrengthDelegate's onSelect method
        
        // Start the update timer
        startSimpleTimer();
        System.println("Timer started");
    }
    
    // Position callback with correct type signature
    function onPositionCallback(posInfo as Position.Info) as Void {
        // Only process if we have valid location info
        if (posInfo != null) {
            // Pass position data to wind tracker
            if (mWindTracker != null) {
                mWindTracker.processPositionData(posInfo);
            }
            
            // Process location data in model
            if (mModel != null) {
                var data = mModel.getData();
                if (data["isRecording"] && !(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                    mModel.processLocationData(posInfo);
                }
            }
            
            // Request UI update to reflect changes
            WatchUi.requestUpdate();
        }
    }
    
    // Modified function to start activity recording session with wind strength in name
    function startActivitySession() {
        try {
            // Get wind strength if available
            var sessionName = "Windfoil";
            var windStrength = null;
            if (mModel != null && mModel.getData().hasKey("windStrength")) {
                windStrength = mModel.getData()["windStrength"];
                sessionName = "Windfoil " + windStrength; // Add wind strength to name
                System.println("Creating session with name: " + sessionName);
            }
            
            // Create activity recording session
            var sessionOptions = {
                :name => sessionName,
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC
            };
            
            // Create session with the name including wind strength
            mSession = ActivityRecording.createSession(sessionOptions);
            
            // Create custom FitContributor fields for important metadata
            createFitContributorFields(sessionName, windStrength);
            
            // Start the session
            mSession.start();
            System.println("Activity recording started as: " + sessionName);
            
            // Set initial wind direction if available
            if (mModel != null && mModel.getData().hasKey("initialWindAngle")) {
                var windAngle = mModel.getData()["initialWindAngle"];
                System.println("Setting initial wind angle: " + windAngle);
                
                // Initialize the WindTracker with the manual direction
                if (mWindTracker != null) {
                    mWindTracker.setInitialWindDirection(windAngle);
                    System.println("WindTracker initialized with direction: " + windAngle);
                    
                    // Update the FitContributor field with wind direction
                    if (mWindDirectionField != null) {
                        mWindDirectionField.setData(windAngle);
                    }
                }
            }
        } catch (e) {
            System.println("Error with activity recording: " + e.getErrorMessage());
        }
    }
    
    // Create FitContributor fields for the session - now includes LAP field types
    function createFitContributorFields(sessionName, windStrength) {
        try {
            // Check if the session is valid
            if (mSession == null) {
                System.println("Session is null, can't create FitContributor fields");
                return;
            }
            
            // Create wind range field as a numeric code (much more reliable)
            var windRangeCode = 0;
            if (windStrength != null) {
                if (windStrength.find("7-10") >= 0) {
                    windRangeCode = 7;  // Starting value of range
                } else if (windStrength.find("10-13") >= 0) {
                    windRangeCode = 10;
                } else if (windStrength.find("13-16") >= 0) {
                    windRangeCode = 13;
                } else if (windStrength.find("16-19") >= 0) {
                    windRangeCode = 16;
                } else if (windStrength.find("19-22") >= 0) {
                    windRangeCode = 19;
                } else if (windStrength.find("22-25") >= 0) {
                    windRangeCode = 22;
                } else if (windStrength.find("25+") >= 0) {
                    windRangeCode = 25;
                }
            }
            
            // Create numeric fields for SESSION
            mWindStrengthField = mSession.createField(
                "windLow",              // Field for low end of range
                1,                      // Field ID
                FitContributor.DATA_TYPE_UINT8, 
                { :mesgType => FitContributor.MESG_TYPE_SESSION }
            );
            
            // Set the wind strength value
            if (mWindStrengthField != null) {
                mWindStrengthField.setData(windRangeCode);
                System.println("Created wind range field: " + windRangeCode);
            }
            
            // If we have wind direction, add that field
            if (mModel != null && mModel.getData().hasKey("initialWindAngle")) {
                var windAngle = mModel.getData()["initialWindAngle"];
                
                // Create wind direction as integer
                mWindDirectionField = mSession.createField(
                    "windDir",             
                    2,                      
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_SESSION }
                );
                
                // Store as integer value (0-359)
                if (mWindDirectionField != null) {
                    mWindDirectionField.setData(windAngle.toNumber());
                    System.println("Created wind direction field: " + windAngle);
                }
            }
            
            // Create LAP custom fields
            // 1. Percent on Foil - 2 digit integer
            mLapPctOnFoilField = mSession.createField(
                "pctOnFoil",
                3,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            
            // 2. VMG Upwind - 3 digits with 1 decimal point
            mLapVMGUpField = mSession.createField(
                "vmgUp",
                4,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :scale => 10 }
            );
            
            // 3. VMG Downwind - 3 digits with 1 decimal point
            mLapVMGDownField = mSession.createField(
                "vmgDown",
                5,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :scale => 10 }
            );
            
            // 4. Tack Seconds - 4 digits with 1 decimal
            mLapTackSecField = mSession.createField(
                "tackSec",
                6,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :scale => 10 }
            );
            
            // 5. Tack Meters - 4 digits with 1 decimal
            mLapTackMtrField = mSession.createField(
                "tackMtr",
                7,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :scale => 10 }
            );
            
            // 6. Wind Direction - duplicated in lap
            mLapWindDirectionField = mSession.createField(
                "windDir",
                8,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            
            // 7. Wind Strength - duplicated in lap
            mLapWindStrengthField = mSession.createField(
                "windStr",
                9,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            
            // 8. Average Tack Angle - 2 digit integer
            mLapAvgTackAngleField = mSession.createField(
                "avgTackAng",
                10,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            
            // Set initial values for lap fields if we have wind data
            if (windRangeCode > 0 && mLapWindStrengthField != null) {
                mLapWindStrengthField.setData(windRangeCode);
            }
            
            if (mModel != null && mModel.getData().hasKey("initialWindAngle") && mLapWindDirectionField != null) {
                var windAngle = mModel.getData()["initialWindAngle"].toNumber();
                mLapWindDirectionField.setData(windAngle);
            }
            
            System.println("All lap custom fields created successfully");
            
        } catch (e) {
            System.println("Error creating FitContributor fields: " + e.getErrorMessage());
        }
    }
    
    // New function to add a lap marker with all custom fields
    // New function to add a lap marker with all custom fields
    function addLapMarker() {
        if (mSession != null && mSession.isRecording()) {
            try {
                System.println("Adding lap marker with custom fields");
                
                // Get current position if available
                var currentPosition = null;
                
                // Try to get the most recent position from the Position module
                try {
                    currentPosition = Position.getInfo();
                    System.println("Got current position for lap marker");
                } catch (ex) {
                    System.println("Error getting position: " + ex.getErrorMessage());
                }
                
                // Notify WindTracker of the lap change first, passing position info
                if (mWindTracker != null) {
                    mWindTracker.onLapMarked(currentPosition);
                }
                
                // Get current data from model
                var data = mModel.getData();
                
                // Get wind and lap data from WindTracker
                var windData = mWindTracker.getWindData();
                var lapData = mWindTracker.getLapData();
                
                // 1. Percent on Foil - now using lap-specific calculation from WindTracker
                if (mLapPctOnFoilField != null && lapData != null && lapData.hasKey("pctOnFoil")) {
                    var pctOnFoil = lapData["pctOnFoil"].toNumber();
                    mLapPctOnFoilField.setData(pctOnFoil);
                    System.println("Lap PctOnFoil: " + pctOnFoil + "% (lap-specific)");
                } 
                // Fallback to model's overall value if lap-specific not available
                else if (mLapPctOnFoilField != null && data.hasKey("percentOnFoil")) {
                    var pctOnFoil = data["percentOnFoil"].toNumber();
                    mLapPctOnFoilField.setData(pctOnFoil);
                    System.println("Lap PctOnFoil: " + pctOnFoil + "% (overall)");
                }
                
                // 2 & 3. VMG (Upwind & Downwind) - now using lap averages
                if (lapData != null) {
                    // Get lap-specific VMG values
                    var vmgUpValue = 0;
                    var vmgDownValue = 0;
                    
                    if (lapData.hasKey("vmgUp")) {
                        vmgUpValue = (lapData["vmgUp"] * 10).toNumber(); // Scale by 10 for 1 decimal place
                        if (mLapVMGUpField != null) {
                            mLapVMGUpField.setData(vmgUpValue);
                            System.println("Lap VMG Upwind: " + (vmgUpValue/10.0) + " (lap average)");
                        }
                    }
                    
                    if (lapData.hasKey("vmgDown")) {
                        vmgDownValue = (lapData["vmgDown"] * 10).toNumber(); // Scale by 10 for 1 decimal place
                        if (mLapVMGDownField != null) {
                            mLapVMGDownField.setData(vmgDownValue);
                            System.println("Lap VMG Downwind: " + (vmgDownValue/10.0) + " (lap average)");
                        }
                    }
                }
                // Fallback to instantaneous values if needed
                else if (windData != null && windData.hasKey("valid") && windData["valid"]) {
                    var vmgValue = 0;
                    if (windData.hasKey("currentVMG")) {
                        vmgValue = (windData["currentVMG"] * 10).toNumber(); // Scale by 10 for 1 decimal place
                    }
                    
                    var isUpwind = false;
                    if (windData.hasKey("currentPointOfSail")) {
                        isUpwind = (windData["currentPointOfSail"] == "Upwind");
                    }
                    
                    // Set VMG in appropriate field based on point of sail
                    if (isUpwind && mLapVMGUpField != null) {
                        mLapVMGUpField.setData(vmgValue);
                        // Set downwind to 0
                        if (mLapVMGDownField != null) {
                            mLapVMGDownField.setData(0);
                        }
                        System.println("Lap VMG Upwind: " + (vmgValue/10.0) + " (current)");
                    } else if (!isUpwind && mLapVMGDownField != null) {
                        mLapVMGDownField.setData(vmgValue);
                        // Set upwind to 0
                        if (mLapVMGUpField != null) {
                            mLapVMGUpField.setData(0);
                        }
                        System.println("Lap VMG Downwind: " + (vmgValue/10.0) + " (current)");
                    }
                }
                
                // 6. Wind Direction
                if (mLapWindDirectionField != null && windData.hasKey("windDirection")) {
                    var windDir = windData["windDirection"].toNumber();
                    mLapWindDirectionField.setData(windDir);
                    System.println("Lap Wind Direction: " + windDir);
                }
                
                // 8. Average Tack Angle - already using lap-specific values
                if (mLapAvgTackAngleField != null && lapData.hasKey("avgTackAngle")) {
                    var avgTackAngle = lapData["avgTackAngle"].toNumber();
                    mLapAvgTackAngleField.setData(avgTackAngle);
                    System.println("Lap Avg Tack Angle: " + avgTackAngle + " (lap-specific)");
                }
                
                // 4 & 5. Tack Time and Distance
                if (lapData != null) {
                    // Time since last tack in this lap
                    if (lapData.hasKey("tackSec") && mLapTackSecField != null) {
                        var tackTimeValue = (lapData["tackSec"] * 10).toNumber(); // Scale by 10 for 1 decimal place
                        mLapTackSecField.setData(tackTimeValue);
                        System.println("Lap Tack Seconds: " + (tackTimeValue/10.0));
                    }
                    
                    // Distance related to tack
                    if (lapData.hasKey("tackMtr") && mLapTackMtrField != null) {
                        var tackDistValue = (lapData["tackMtr"] * 10).toNumber(); // Scale by 10 for 1 decimal place
                        mLapTackMtrField.setData(tackDistValue);
                        System.println("Lap Tack Meters: " + (tackDistValue/10.0));
                    }
                }
                
                // 7. Wind Strength
                if (mLapWindStrengthField != null && mWindStrengthField != null) {
                    // Use the same value as the session field
                    var windStr = mWindStrengthField.getData();
                    mLapWindStrengthField.setData(windStr);
                    System.println("Lap Wind Strength: " + windStr);
                }
                
                // Add lap-to-date VMG to debug log
                if (lapData != null && lapData.hasKey("lapVMG")) {
                    System.println("Lap-to-date VMG: " + lapData["lapVMG"].format("%.2f") + " knots");
                }
                
                // Add the lap marker after setting all fields
                mSession.addLap();
                System.println("Lap marker added successfully");
                
            } catch (e) {
                System.println("Error adding lap marker: " + e.getErrorMessage());
            }
        } else {
            System.println("Cannot add lap marker - session not recording");
        }
    }
    
    // Basic function to record wind data in the activity
    function updateSessionWithWindData(windStrength) {
        if (mSession != null && mSession.isRecording()) {
            try {
                // Store wind data in model for saving in app storage
                if (mModel != null) {
                    mModel.getData()["windStrength"] = windStrength;
                    System.println("Wind strength stored in model: " + windStrength);
                }
                
                // Update FitContributor field if available
                if (mWindStrengthField != null) {
                    mWindStrengthField.setData(windStrength);
                    System.println("Updated wind strength field: " + windStrength);
                }
                
                // Add a lap marker to indicate where wind strength was recorded
                // This is the most basic API call that should work on all devices
                mSession.addLap();
                System.println("Added lap marker for wind strength: " + windStrength);
                
            } catch (e) {
                System.println("Error adding wind data: " + e.getErrorMessage());
            }
        }
    }
    
    // Get the wind tracker instance
    function getWindTracker() {
        return mWindTracker;
    }
    
    // Create and start a simple timer without custom callback class
    function startSimpleTimer() {
        if (mTimer == null) {
            mTimer = new Timer.Timer();
        }
        
        // Use a simple direct callback instead of a custom class
        mTimer.start(method(:onTimerTick), 1000, true);
        mTimerRunning = true;
        System.println("Simple timer running");
    }
    
    // Direct timer callback function - safe implementation
    function onTimerTick() {
        try {
            processData();
        } catch (e) {
            System.println("Error in timer processing: " + e.getErrorMessage());
        }
    }
    
    // Process data and update UI - modified to use real position data when available
    function processData() {
        if (mModel != null) {
            var data = mModel.getData();
            
            // Only process data if recording and not paused
            if (data["isRecording"] && !(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                // Use simulated data only when position is not enabled
                if (!mPositionEnabled) {
                    var mockSpeed = (System.getTimer() % 20000) / 1000.0; // 0-20 m/s
                    var mockHeading = (System.getTimer() / 1000) % 360; // Simulated heading
                    var info = {
                        :speed => mockSpeed,
                        :heading => mockHeading,
                        :altitude => 100,
                        :accuracy => 10
                    };
                    mModel.processLocationData(info);
                    
                    // Also process in wind tracker
                    mWindTracker.processPositionData(info);
                }
                
                // Update model data
                mModel.updateData();
            } else {
                // Still update time display when paused
                if (data.hasKey("sessionPaused") && data["sessionPaused"]) {
                    mModel.updateTimeDisplay();
                }
            }
            
            // Request UI update regardless of state
            WatchUi.requestUpdate();
        }
    }

    // onStop() is called when the application is exiting
    function onStop(state) {
        System.println("App stopping - saving activity data");
        
        // Emergency timestamp save first (always works)
        try {
            var storage = Application.Storage;
            storage.setValue("appStopTime", Time.now().value());
            System.println("Emergency timestamp saved");
        } 
        catch (e) {
            System.println("Even timestamp save failed");
        }
        
        // Attempt full data save if model is available
        if (mModel != null) {
            try {
                var saveResult = mModel.saveActivityData();
                if (saveResult) {
                    System.println("Activity data saved successfully");
                } else {
                    System.println("Activity save reported failure");
                }
            } 
            catch (e) {
                System.println("Error in onStop when saving: " + e.getErrorMessage());
                
                // Try one more emergency direct save
                try {
                    var storage = Application.Storage;
                    var finalBackup = {
                        "date" => Time.now().value(),
                        "onStopEmergency" => true
                    };
                    storage.setValue("onStop_emergency", finalBackup);
                    System.println("OnStop emergency save succeeded");
                } catch (e2) {
                    System.println("All save attempts failed");
                }
            }
        } 
        else {
            System.println("Model not available in onStop");
        }
    }

    // Function to get initial view - modified to start with wind picker
    function getInitialView() {
        // Initialize the model if not already initialized
        if (mModel == null) {
            mModel = new FoilTrackerModel();
        }
        
        // Create a wind strength picker view as the initial view
        var windView = new WindStrengthPickerView(mModel);
        var windDelegate = new StartupWindStrengthDelegate(mModel, self);
        windDelegate.setPickerView(windView);
        
        // Return the wind picker as initial view
        return [windView, windDelegate];
    }
}