// Minimize normal windows on the current virtual desktop while leaving
// panels and layer-shell surfaces visible. A second invocation restores only
// the windows this script minimized, preserving windows that were already
// minimized before Show Desktop was requested.

let minimizedByPlasmarchy = [];

function isOnCurrentDesktop(window) {
    return window.onAllDesktops || window.desktops.includes(workspace.currentDesktop);
}

function canHide(window) {
    return window.normalWindow && window.minimizable && !window.minimized && isOnCurrentDesktop(window);
}

function minimizeCurrentWindows() {
    minimizedByPlasmarchy = [];
    workspace.windowList().forEach((window) => {
        if (!canHide(window)) return;
        minimizedByPlasmarchy.push(window);
        window.minimized = true;
    });
}

function restoreWindows() {
    const windows = minimizedByPlasmarchy;
    minimizedByPlasmarchy = [];

    windows.forEach((window) => {
        try {
            if (window && window.minimized) window.minimized = false;
        } catch (error) {
            // The window may have closed while the desktop was visible.
        }
    });
}

function toggleDesktop() {
    if (minimizedByPlasmarchy.length > 0) restoreWindows();
    else minimizeCurrentWindows();
}

registerShortcut(
    "Plasmarchy Show Desktop",
    "Plasmarchy Show Desktop",
    "",
    toggleDesktop
);
