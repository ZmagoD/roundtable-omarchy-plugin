import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

// One bar icon and one panel for Roundtable: whether the local service is up,
// what each room is doing, and — the reason this widget exists — whether a
// participant has stopped mid-turn waiting for someone to approve a tool call.
// That is the one thing a room will not tell you unless its window is open.
//
// Reading only. Approving a tool call means seeing what it wants to run, so it
// stays in the room where the request and its context are; this offers the way
// in, not a yes/no button a stray click could hit.
Panel {
  id: root
  moduleName: "io.github.zmagod.roundtable"
  ipcTarget: "io.github.zmagod.roundtable"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color barIconColor: service.running ? barForeground : Qt.darker(barForeground, 1.55)

  // One word for the pill, so the title beside it keeps its room.
  readonly property string stateWord: {
    if (!service.checked) return "Checking…"
    if (!service.installed) return "Missing"
    if (!service.running) return "Stopped"
    if (service.error !== "") return "Unreachable"
    if (service.waiting > 0) return "Waiting"
    if (service.working > 0) return "Working"
    if (service.queued > 0) return "Queued"
    return "Idle"
  }

  // And a sentence under it. What is waiting on a person comes first, because
  // that is the only line here that asks for anything.
  readonly property string headline: {
    if (!service.checked) return "Asking the service"
    if (!service.installed) return "roundtable is not on your PATH"
    if (!service.running) return "Start it here, or run roundtable start"
    if (service.error !== "") return service.error
    if (service.waiting > 0) return plural(service.waiting, "turn waiting for you", "turns waiting for you")
    if (service.working > 0) return plural(service.working, "turn running", "turns running")
    if (service.queued > 0) return plural(service.queued, "turn queued", "turns queued")
    if (service.roomCount === 0) return "No rooms yet"
    return plural(service.roomCount, "room", "rooms") + " · " +
           plural(service.participants, "participant", "participants")
  }

  function plural(count, one, many) {
    return count + " " + (count === 1 ? one : many)
  }

  // What a room is doing, in the order that matters: something waiting on a
  // person outranks work in progress, which outranks a full roster.
  function roomState(room) {
    if (Number(room.waiting_for_approval) > 0) return "waiting for you"
    if (Number(room.running) > 0) return plural(Number(room.running), "working", "working")
    if (Number(room.queued) > 0) return plural(Number(room.queued), "queued", "queued")
    return plural(Number(room.participants), "participant", "participants")
  }

  function roomNeedsYou(room) {
    return Number(room.waiting_for_approval) > 0
  }

  function openBrowser() {
    Util.execArgv([service.command, "open"])
    settleTimer.restart()
  }

  function openTerminal() {
    Util.execArgv(["omarchy-launch-or-focus-tui", service.command, "tui"])
    settleTimer.restart()
  }

  function startService() {
    Util.execArgv([service.command, "start"])
    settleTimer.restart()
  }

  function stopService() {
    Util.execArgv([service.command, "stop"])
    settleTimer.restart()
  }

  function toggleService() {
    if (!service.installed) return
    service.running ? stopService() : startService()
  }

  Service {
    id: service
    settings: root.settings
  }

  // Start and stop take a moment to land. Poll once after, so the panel does
  // not sit on the old answer until the next tick.
  Timer {
    id: settleTimer
    interval: 1200
    repeat: false
    onTriggered: service.refresh()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { service.refresh(); return "ok" }
    function status(): string { return root.headline }
  }

  // The bar sizes this slot from what the root reports, and the root is an
  // Item with no size of its own: without this the widget is a zero-width gap.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Roundtable — " + root.headline
    iconComponent: Component {
      Item {
        RoundtableIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barIconColor
          badgeColor: root.urgent
          muted: !service.running
          waiting: service.waiting > 0
        }
      }
    }
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) root.openBrowser()
      else if (buttonCode === Qt.MiddleButton) service.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(460))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        var key = String(t).toLowerCase()
        if (key === "o") root.openBrowser()
        else if (key === "t") root.openTerminal()
        else if (key === "r") service.refresh()
        else if (key === "s") root.toggleService()
      }

      ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.spacing.sm

        PanelHero {
          Layout.fillWidth: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          title: "Roundtable"
          meta: root.headline
          detail: root.stateWord
          iconComponent: Component {
            Item {
              RoundtableIcon {
                anchors.centerIn: parent
                iconSize: Style.font.display
                color: service.waiting > 0 ? root.urgent : root.foreground
                badgeColor: root.urgent
                muted: !service.running
              }
            }
          }
        }

        PanelSeparator {
          Layout.fillWidth: true
          foreground: root.foreground
          visible: service.running
        }

        PanelSectionHeader {
          Layout.fillWidth: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          text: "Rooms"
          visible: service.running && service.rooms.length > 0
        }

        Repeater {
          model: service.running ? service.rooms : []

          RowLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: Style.spacing.sm

            Text {
              Layout.fillWidth: true
              text: String(modelData.name || "")
              elide: Text.ElideRight
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              text: root.roomState(modelData)
              textFormat: Text.PlainText
              color: root.roomNeedsYou(modelData) ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: service.running && service.rooms.length === 0
          text: "Open Roundtable to make the first one."
          wrapMode: Text.WordWrap
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        PanelSeparator {
          Layout.fillWidth: true
          foreground: root.foreground
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.sm

          PanelActionButton {
            iconText: "󰖟"
            tooltipText: "Open Roundtable (o)"
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: service.installed
            onClicked: root.openBrowser()
          }

          PanelActionButton {
            iconText: "󰆍"
            tooltipText: "Open the terminal client (t)"
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: service.installed
            onClicked: root.openTerminal()
          }

          PanelActionButton {
            iconText: "󰑐"
            tooltipText: "Check again (r)"
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: !service.busy
            onClicked: service.refresh()
          }

          Item { Layout.fillWidth: true }

          PanelActionButton {
            iconText: "󰐥"
            tooltipText: service.running ? "Stop the service (s)" : "Start the service (s)"
            foreground: service.running ? root.foreground : root.urgent
            fontFamily: root.fontFamily
            enabled: service.installed
            onClicked: root.toggleService()
          }
        }
      }
    }
  }
}
