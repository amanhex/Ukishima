import QtQuick
import Quickshell
import Quickshell.Services.Pam

Scope {
    id: root

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    // set on success — surfaces fade out while the compositor still holds the lock
    property bool closing: false
    // Last PAM message for UI (e.g. "Account locked", "Password: ")
    property string pamMessage: ""
    property bool pamIsError: false
    // Shown on the lock surface. PAM's own idea of who it is authenticating is
    // authoritative; the environment is only a fallback for the moment before
    // the first start(), when pam.user may not be resolved yet.
    readonly property string userName: pam.user || Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""

    signal unlocked()
    signal failed()

    function tryUnlock() {
        if (currentText === "" || unlockInProgress) {
            console.log("[lock] tryUnlock ignored empty/active");
            return ;
        }
        console.log("[lock] tryUnlock len=" + currentText.length);
        unlockInProgress = true;
        showFailure = false;
        pamMessage = "";
        var ok = pam.start();
        console.log("[lock] pam.start()=" + ok + " active=" + pam.active);
        if (!ok) {
            unlockInProgress = false;
            showFailure = true;
            pamMessage = "Could not start PAM";
        }
    }

    onCurrentTextChanged: {
        // typing clears failure banner (but not while checking)
        if (!unlockInProgress)
            showFailure = false;

    }

    PamContext {
        id: pam

        // Relative like official example — resolves to lockscreen/pam/
        configDirectory: "pam"
        config: "password.conf"
        onMessageChanged: {
            root.pamMessage = message;
            root.pamIsError = messageIsError;
            // surface lockMessage like Caelestia: keep faillock text
            if (message && message.length > 0)
                console.log("[lock] pam msg: [" + message + "] err=" + messageIsError + " req=" + responseRequired);

        }
        // Official example pattern (this. prefix matters in some Qt versions)
        onPamMessage: {
            if (this.responseRequired) {
                console.log("[lock] responding len=" + root.currentText.length);
                this.respond(root.currentText);
            }
        }
        // Caelestia fallback pattern — same respond, harmless if already responded
        // (respond() is ignored when not required, per qml.cpp)
        onResponseRequiredChanged: {
            if (responseRequired) {
                console.log("[lock] responseRequiredChanged -> respond");
                respond(root.currentText);
            }
        }
        onCompleted: (result) => {
            console.log("[lock] completed=" + result + " (0=Success 1=Failed 2=Error 3=MaxTries)");
            if (result === PamResult.Success) {
                root.unlocked();
            } else {
                if (result === PamResult.MaxTries)
                    root.pamMessage = "Too many tries";
                else if (result === PamResult.Error)
                    root.pamMessage = (root.pamMessage.length > 0 ? root.pamMessage : "PAM error");
                else if (result === PamResult.Failed)
                    root.pamMessage = (root.pamMessage.indexOf("locked") >= 0 ? root.pamMessage : "Incorrect password");
                root.currentText = "";
                root.showFailure = true;
                root.failed();
            }
            root.unlockInProgress = false;
        }
        onError: (error) => {
            console.log("[lock] pam error=" + error);
            root.pamMessage = "Auth error " + error;
            root.currentText = "";
            root.showFailure = true;
            root.unlockInProgress = false;
        }
    }

}
