using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application;

// Custom save/discard dialog view
class SaveDialogView extends WatchUi.View {
    private var mModel;
    
    function initialize(model) {
        View.initialize();
        mModel = model;
    }
    
    function onUpdate(dc) {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Draw title centered
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height/4 - 20, Graphics.FONT_MEDIUM, "Save?", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw stats in the middle
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var yPos = height/2 - 20;
        
        // Draw each line separately
        if (mModel != null) {
            var data = mModel.getData();
            var maxSpeed = data.hasKey("maxSpeed") ? data["maxSpeed"].format("%.1f") : "0.0";
            var max3sSpeed = data.hasKey("max3sSpeed") ? data["max3sSpeed"].format("%.1f") : "0.0";
            var percentOnFoil = data.hasKey("percentOnFoil") ? data["percentOnFoil"].format("%.0f") : "0";
            
            dc.drawText(width/2, yPos, Graphics.FONT_SMALL, "Max: " + maxSpeed + " kt", Graphics.TEXT_JUSTIFY_CENTER);
            yPos += 25;
            dc.drawText(width/2, yPos, Graphics.FONT_SMALL, "Max 3s: " + max3sSpeed + " kt", Graphics.TEXT_JUSTIFY_CENTER);
            yPos += 25;
            dc.drawText(width/2, yPos, Graphics.FONT_SMALL, "On Foil: " + percentOnFoil + "%", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        // Draw save (top right) and discard (bottom left) options
        
        // Top right - CONFIRM (aligned with Select button)
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(3*width/4, height/4, Graphics.FONT_SMALL, "Confirm", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(3*width/4, height/4 + 20, Graphics.FONT_TINY, "(Select)", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Bottom left - DISCARD (aligned with Down button) - small font
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/4, 3*height/4, Graphics.FONT_TINY, "discard", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/4, 3*height/4 + 15, Graphics.FONT_TINY, "(down)", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// Custom save/discard dialog delegate
class SaveDialogDelegate extends WatchUi.BehaviorDelegate {
    private var mModel;
    private var mApp;
    
    function initialize(model, app) {
        BehaviorDelegate.initialize();
        mModel = model;
        mApp = app;
    }
    
    // Use back button to return to previous screen
    function onBack() {
        // Go back to previous screen without saving or discarding
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
    
    // Use select button to save (Confirm)
    function onSelect() {
        saveActivity();
        return true;
    }
    
    // Use down button to discard
    function onNextPage() {
        discardActivity();
        return true;
    }
    
    // Function to save the activity
    function saveActivity() {
        System.println("Saving activity");
        
        // Save data in the model
        if (mModel != null) {
            mModel.saveActivityData();
            
            // Mark as complete
            var data = mModel.getData();
            data["sessionComplete"] = true;
        }
        
        // Save the activity recording session
        if (mApp != null && mApp has :mSession && mApp.mSession != null && mApp.mSession.isRecording()) {
            try {
                mApp.mSession.stop();
                mApp.mSession.save();
                System.println("Activity recording saved");
            } catch (e) {
                System.println("Error saving activity: " + e.getErrorMessage());
            }
        }
        
        // Exit the app
        System.exit();
    }
    
    // Function to discard the activity
    function discardActivity() {
        System.println("Discarding activity");
        
        // Mark as complete in the model so we don't auto-save
        if (mModel != null) {
            var data = mModel.getData();
            data["sessionComplete"] = true;
        }
        
        // Discard the activity recording session
        if (mApp != null && mApp has :mSession && mApp.mSession != null && mApp.mSession.isRecording()) {
            try {
                mApp.mSession.stop();
                mApp.mSession.discard();
                System.println("Activity recording discarded");
            } catch (e) {
                System.println("Error discarding activity: " + e.getErrorMessage());
            }
        }
        
        // Exit the app
        System.exit();
    }
}