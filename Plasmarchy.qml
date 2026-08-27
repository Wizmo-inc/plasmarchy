import QtQuick
import Quickshell
import Quickshell.Io

// Marketplace-compatible, non-mutating service entry point. Plasmarchy is a
// complete desktop integration, so its actual installation remains the guided
// and reversible process documented in README.md.
Item {
  id: root

  // Injected by omarchy-shell's plugin service loader.
  property var shell: null
  property string omarchyPath: ""
  property var manifest: null
  property var pluginRegistry: null

  readonly property string currentDesktop: Quickshell.env("XDG_CURRENT_DESKTOP")
  readonly property bool runningInPlasma: currentDesktop.toLowerCase().indexOf("kde") !== -1

  function statusText() {
    return JSON.stringify({
      plugin: "Plasmarchy",
      installed: true,
      desktop: currentDesktop,
      plasma: runningInPlasma,
      setup: "Follow the guided installation in README.md"
    })
  }

  Component.onCompleted: console.info(
    "Plasmarchy marketplace service loaded; full integration uses guided setup"
  )

  IpcHandler {
    target: "plasmarchy"

    function status(): string {
      return root.statusText()
    }
  }
}
