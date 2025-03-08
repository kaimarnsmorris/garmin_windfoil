using Toybox.WatchUi;
using Toybox.System;
using Toybox.Application;

// VMGDelegate class to handle button presses on VMG view
class VMGDelegate extends WatchUi.BehaviorDelegate {
    private var mView;
    private var mModel;
    private var mApp;
    private var mWindTracker;
    
    // Constructor
    function initialize(view, model, app) {
        BehaviorDelegate.initialize();
        mView = view;
        mModel = model;
        mApp = app;
        mWindTracker = app.getWindTracker();
    }
    
    // Handle menu button press
    function onMenu() {
        // Show the menu when the menu button is pressed
        WatchUi.pushView(new FoilTrackerMenuView(), new FoilTrackerMenuDelegate(mModel), WatchUi.SLIDE_UP);
        return true;
    }
    
    // Handle select button press - Reset wind direction to initial user input
    function onSelect() {
        if (mWindTracker != null) {
            // Reset the wind tracker to use the initial user input and unlock
            mWindTracker.unlockWindDirection();
            mWindTracker.resetToManualDirection();
            
            // Log the reset action
            System.println("Wind direction reset to manual input");
            
            // Request UI update to reflect changes
            WatchUi.requestUpdate();
        }
        return true;
    }
    
    // Handle back button press - Lock wind direction instead of ending session
    function onBack() {
        if (mWindTracker != null) {
            // Lock the wind direction at current value
            mWindTracker.lockWindDirection();
            
            // Log the action
            System.println("Wind direction locked");
            
            // Request UI update to reflect changes
            WatchUi.requestUpdate();
        }
        return true;
    }
    
    // Handle previous page button (up) - Go back to main view
    function onPreviousPage() {
        // Switch back to the main FoilTrackerView
        var view = new FoilTrackerView(mModel);
        var delegate = new FoilTrackerDelegate(view, mModel, mApp.getWindTracker());
        WatchUi.switchToView(view, delegate, WatchUi.SLIDE_UP);
        return true;
    }
    
    // Handle next page button (down) - Stay on this page (VMG view)
    function onNextPage() {
        // Already on VMG view, do nothing but force an update
        WatchUi.requestUpdate();
        return true;
    }
    
    // NEW FUNCTION: Handle light button press - Add lap marker with custom fields
    function onLight() {
        // Check if the activity is recording
        var data = mModel.getData();
        var isActive = false;
        
        // Only add lap when activity is recording and not paused
        if (data.hasKey("isRecording") && data["isRecording"]) {
            if (!(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                isActive = true;
            }
        }
        
        if (isActive) {
            // Add a lap marker with all custom fields
            mApp.addLapMarker();
            
            // Show lap feedback in the view
            if (mView has :showLapFeedback) {
                mView.showLapFeedback();
            }
            
            // Optional: WatchUi.playTone(Attention.TONE_LAP); // Play a tone if needed
            System.println("Lap marker added from VMG view");
        } else {
            System.println("Cannot add lap marker - not recording or paused");
        }
        
        return true;
    }
    
    // Override the onShow handler to ensure view is updated when shown
    function onShow() {
        // Force an update when view is shown
        System.println("VMGDelegate.onShow() - Forcing UI update");
        WatchUi.requestUpdate();
        return true;
    }
}