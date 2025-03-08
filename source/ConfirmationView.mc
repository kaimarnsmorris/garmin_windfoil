using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application;

// Confirmation dialog for exiting while recording
class ConfirmationView extends WatchUi.View {
    private var mPrompt;
    
    function initialize(prompt) {
        View.initialize();
        mPrompt = prompt;
    }
    
    function onLayout(dc) {
        // Layout resources
    }
    
    function onUpdate(dc) {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Draw confirmation text
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height/2 - 30, Graphics.FONT_MEDIUM, mPrompt, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, height/2 + 10, Graphics.FONT_SMALL, "Press SELECT to confirm", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, height/2 + 35, Graphics.FONT_SMALL, "Press BACK to cancel", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// Confirmation delegate - modified to show custom save/discard dialog
class ConfirmationDelegate extends WatchUi.BehaviorDelegate {
    private var mModel;
    private var mApp;
    
    function initialize(model) {
        BehaviorDelegate.initialize();
        mModel = model;
        mApp = Application.getApp();
    }
    
    function onSelect() {
        // End recording immediately
        if (mModel != null) {
            var data = mModel.getData();
            data["isRecording"] = false;
            data["sessionPaused"] = false;
            data["sessionComplete"] = false; // Will be set to true when saved
        }
        
        // Show our custom save dialog
        var saveView = new SaveDialogView(mModel);
        var saveDelegate = new SaveDialogDelegate(mModel, mApp);
        
        // Push the view
        WatchUi.pushView(saveView, saveDelegate, WatchUi.SLIDE_LEFT);
        
        return true;
    }
    
    function onBack() {
        // Cancel exit - go back to the main view
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}