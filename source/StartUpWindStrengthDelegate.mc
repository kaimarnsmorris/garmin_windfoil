// Fixed StartUpWindStrengthDelegate.mc to return to app launcher

using Toybox.WatchUi;
using Toybox.System;

// Wind Strength Picker Delegate for initial app startup
class StartupWindStrengthDelegate extends WatchUi.BehaviorDelegate {
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
    
    function onNextPage() {
        if (mPickerView != null) {
            var options = mModel.getWindStrengthOptions();
            if (mPickerView.mSelectedIndex < options.size() - 1) {
                mPickerView.mSelectedIndex++;
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
    
    function onPreviousPage() {
        if (mPickerView != null) {
            if (mPickerView.mSelectedIndex > 0) {
                mPickerView.mSelectedIndex--;
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
    
    function onSelect() {
        try {
            // Get selected wind strength from the view
            if (mPickerView != null) {
                var selectedIndex = mPickerView.mSelectedIndex;
                
                // Set wind strength to model
                if (mModel != null) {
                    var windStrength = mModel.getWindStrengthOptions()[selectedIndex];
                    mModel.setWindStrength(selectedIndex);
                    
                    System.println("Selected wind strength at startup: " + windStrength);
                }
            }
            
            // Now go to wind angle picker instead of starting the session
            var windAngleView = new WindAnglePickerView(mModel);
            var windAngleDelegate = new WindAnglePickerDelegate(mModel, mApp);
            windAngleDelegate.setPickerView(windAngleView);
            
            WatchUi.switchToView(windAngleView, windAngleDelegate, WatchUi.SLIDE_LEFT);
        } catch (e) {
            System.println("Error in wind strength selection: " + e.getErrorMessage());
            
            // Fall back to main view if there's an error
            var view = new FoilTrackerView(mModel);
            var delegate = new FoilTrackerDelegate(view, mModel, mApp.getWindTracker());
            WatchUi.switchToView(view, delegate, WatchUi.SLIDE_IMMEDIATE);
        }
        
        return true;
    }
    
    // Handle back button press
    function onBack() {
        // When back is pressed on initial wind picker, just return to the app launcher
        // Let the system handle the event instead of trying to manage it ourselves
        return false;
    }
}