import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "AccessModel.js" as Model
import "components"

Panel {
  id: root
  moduleName: "io.github.ef-code.access-profiles"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var profiles: []
  property int selectedIndex: 0
  property var selectedPlan: null
  property var backendStatus: ({ activeProfile: null, preview: null, conflicts: [] })
  property string statusMessage: ""
  property bool statusWarning: false
  property bool loading: false
  property bool confirmRestore: false
  property int nowMs: Date.now()
  property string pendingAction: ""
  property string lastOperationId: ""
  readonly property string backendPath: decodeURIComponent(String(Qt.resolvedUrl("scripts/accessctl")).replace(/^file:\/\//, ""))
  readonly property var selectedProfile: profiles.length > 0 && selectedIndex >= 0 && selectedIndex < profiles.length ? profiles[selectedIndex] : null
  readonly property bool hasActionablePlan: Model.hasActionableChanges(selectedPlan)
  readonly property bool hasBaseline: backendStatus.baselineCaptured === true
  readonly property string barGlyph: backendStatus.preview ? "󰌵" : "󰌵"
  readonly property bool barActive: !!backendStatus.activeProfile || !!backendStatus.preview
  readonly property string barTooltip: Model.barState(backendStatus).label

  function operationId() {
    var parts = []
    for (var i = 0; i < 32; i++) parts.push(Math.floor(Math.random() * 16).toString(16))
    return parts.slice(0, 8).join("") + "-" + parts.slice(8, 12).join("") + "-4" + parts.slice(13, 16).join("") + "-8" + parts.slice(17, 20).join("") + "-" + parts.slice(20).join("")
  }

  function runBackend(args, action) {
    if (backendProcess.running) return
    pendingAction = action
    loading = true
    backendProcess.command = ["bash", backendPath].concat(args)
    backendProcess.running = true
  }

  function load() { runBackend(["recover"], "recover") }
  function refresh() {
    if (profiles.length === 0) load()
    else runBackend(["status"], "status")
  }

  function loadProfiles() { runBackend(["list-profiles"], "profiles") }

  function selectProfile(index) {
    if (index < 0 || index >= profiles.length) return
    selectedIndex = index
    if (selectedProfile) runBackend(["plan", String(selectedProfile.id)], "plan")
  }

  function applyProfile(profileId) {
    for (var i = 0; i < profiles.length; i++) {
      if (String(profiles[i].id) !== String(profileId)) continue
      selectedIndex = i
      applySelected()
      return
    }
    statusMessage = "Unknown profile"
    statusWarning = true
  }

  function planSelected() {
    if (selectedProfile) runBackend(["plan", String(selectedProfile.id)], "plan")
  }

  function previewSelected() {
    if (!selectedProfile || !hasActionablePlan) return
    var id = operationId()
    lastOperationId = id
    runBackend(["preview", String(selectedProfile.id), "--seconds", "30", "--operation-id", id], "preview")
  }

  function applySelected() {
    if (!selectedProfile || !hasActionablePlan) return
    var id = operationId()
    lastOperationId = id
    runBackend(["apply", String(selectedProfile.id), "--operation-id", id], "apply")
  }

  function keepPreview() {
    if (!backendStatus.preview) return
    var id = String(backendStatus.preview.operationId || lastOperationId)
    runBackend(["keep-preview", "--operation-id", id], "keep-preview")
  }

  function cancelPreview() {
    if (!backendStatus.preview) return
    var id = String(backendStatus.preview.operationId || lastOperationId)
    runBackend(["cancel-preview", "--operation-id", id], "cancel-preview")
  }

  function requestRestore() {
    if (!opened) root.open()
    if (!hasBaseline) {
      statusMessage = "No Access baseline has been captured yet."
      statusWarning = false
      return
    }
    confirmRestore = true
  }

  function restoreNow() {
    confirmRestore = false
    var id = operationId()
    lastOperationId = id
    runBackend(["restore", "--operation-id", id], "restore")
  }

  function handleResponse(action, response, exitCode) {
    loading = false
    if (!response || response.ok !== true) {
      statusMessage = String(response && response.error ? response.error : "Access backend failed")
      statusWarning = true
      if (response && response.details && Array.isArray(response.details.conflicts))
        backendStatus.conflicts = response.details.conflicts
      if (action === "restore") refresh()
      return
    }

    statusWarning = false
    if (action === "profiles") {
      profiles = Model.profilesFromResponse(response)
      if (selectedIndex >= profiles.length) selectedIndex = Math.max(0, profiles.length - 1)
      planSelected()
      return
    }
    if (action === "status") {
      backendStatus = response
      if (backendStatus.preview) previewTimer.start()
      else previewTimer.stop()
      if (selectedProfile) planSelected()
      return
    }
    if (action === "plan") {
      selectedPlan = response
      return
    }
    if (action === "recover") {
      loadProfiles()
      return
    }

    statusMessage = action === "preview" ? "Preview active — keep it or revert now." : "Access settings updated."
    refresh()
  }

  onOpenedChanged: {
    if (opened) {
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      refresh()
    } else confirmRestore = false
  }

  Process {
    id: backendProcess
    stdout: StdioCollector { id: backendStdout; waitForEnd: true }
    stderr: StdioCollector { id: backendStderr; waitForEnd: true }
    onExited: {
      var output = String(backendStdout.text || "").trim()
      var response = Model.parseResponse(output)
      if (exitCode !== 0 && response.ok === true) response = { ok: false, error: String(backendStderr.text || "Backend failed") }
      root.handleResponse(root.pendingAction, response, exitCode)
    }
  }

  Timer {
    id: previewTimer
    interval: 1000
    repeat: true
    onTriggered: {
      root.nowMs = Date.now()
      if (root.backendStatus.preview && Number(root.backendStatus.preview.deadline || 0) <= Math.floor(root.nowMs / 1000))
        root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(contentFlick.contentHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0 || dy !== 0) {
          var next = root.selectedIndex + (dx > 0 || dy > 0 ? 1 : -1)
          if (next < 0) next = root.profiles.length - 1
          if (next >= root.profiles.length) next = 0
          root.selectProfile(next)
        }
      }
      onActivateRequested: root.applySelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(key) {
        if (key === "p" || key === "P") root.previewSelected()
        else if (key === "a" || key === "A") root.applySelected()
        else if (key === "r" || key === "R") root.requestRestore()
      }

      Flickable {
        id: contentFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
          id: contentColumn
          width: contentFlick.width
          spacing: Style.space(10)

          RowLayout {
            Layout.fillWidth: true
            Text {
              Layout.fillWidth: true
              text: "ACCESS"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: root.backendStatus.preview ? "Previewing" : (root.backendStatus.activeProfile ? "Active" : "Original")
              color: root.backendStatus.conflicts && root.backendStatus.conflicts.length > 0 ? Color.urgent : root.barForeground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            Layout.fillWidth: true
            text: "Make the desktop easier to see, follow, and control."
            color: Qt.alpha(root.barForeground, 0.78)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          StatusBanner {
            Layout.fillWidth: true
            message: root.statusMessage || (root.backendStatus.preview ? "Previewing " + root.backendStatus.preview.profileId + " — " + Model.formatCountdown(root.backendStatus.preview.deadline, root.nowMs) + " remaining." : "")
            warning: root.statusWarning || (root.backendStatus.conflicts && root.backendStatus.conflicts.length > 0)
            foreground: root.barForeground
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Repeater {
              model: root.profiles
              ProfileCard {
                required property var modelData
                required property int index
                profile: modelData
                selected: index === root.selectedIndex
                foreground: root.barForeground
                onClicked: root.selectProfile(index)
              }
            }
          }

          Text {
            Layout.fillWidth: true
            text: root.selectedProfile ? String(root.selectedProfile.name || "Profile") : "Choose a profile"
            color: root.barForeground
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            Layout.fillWidth: true
            text: root.selectedProfile ? String(root.selectedProfile.description || "") : "Profiles affect only listed settings."
            color: Qt.alpha(root.barForeground, 0.75)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)
            Repeater {
              model: Model.normalizedChanges(root.selectedPlan)
              ChangeRow {
                required property var modelData
                change: modelData
                Layout.fillWidth: true
                foreground: root.barForeground
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Button {
              Layout.fillWidth: true
              text: "Preview 30s"
              enabled: root.hasActionablePlan && !root.loading && !root.backendStatus.preview
              focusable: true
              onClicked: root.previewSelected()
            }
            Button {
              Layout.fillWidth: true
              text: "Apply"
              enabled: root.hasActionablePlan && !root.loading && !root.backendStatus.preview
              focusable: true
              onClicked: root.applySelected()
            }
          }

          RowLayout {
            Layout.fillWidth: true
            visible: !!root.backendStatus.preview
            Button {
              Layout.fillWidth: true
              text: "Keep"
              enabled: !root.loading
              focusable: true
              onClicked: root.keepPreview()
            }
            Button {
              Layout.fillWidth: true
              text: "Revert now"
              enabled: !root.loading
              focusable: true
              onClicked: root.cancelPreview()
            }
          }

          Button {
            Layout.fillWidth: true
            text: "Restore original settings"
            enabled: root.hasBaseline && !root.loading
            focusable: true
            onClicked: root.requestRestore()
          }

          Text {
            Layout.fillWidth: true
            text: "GTK changes affect applications that honor the schema. Monitor scaling and screen-reader support are not managed here."
            color: Qt.alpha(root.barForeground, 0.58)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          ConfirmSheet {
            Layout.fillWidth: true
            visible: root.confirmRestore
            title: "Restore original settings?"
            message: "Access will restore its captured baseline and stop managing the active profile. External changes will be shown as conflicts first."
            foreground: root.barForeground
            onAccepted: root.restoreNow()
            onRejected: root.confirmRestore = false
          }
        }
      }
    }
  }
}
