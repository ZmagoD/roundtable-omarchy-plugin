import QtQuick
import Quickshell.Io

// Polls `roundtable status --json`, which answers whether the local service is
// up and, when it is, what its rooms are doing. One command per tick: the CLI
// already knows where the service is listening, so nothing here has to find a
// port or read a log.
Item {
  id: root

  property var settings: ({})

  // Until the first poll comes back, say nothing rather than "stopped": a
  // widget that flashes the wrong state on login is worse than a blank one.
  property bool checked: false
  property bool installed: true
  property bool running: false
  property string url: ""
  property var rooms: []
  property int roomCount: 0
  property int participants: 0
  property int queued: 0
  property int working: 0
  property int waiting: 0
  property string error: ""

  readonly property bool busy: statusProcess.running
  readonly property string command: {
    var value = settings ? settings.command : ""
    return value === undefined || value === null || String(value) === "" ? "roundtable" : String(value)
  }
  readonly property int refreshIntervalSec: {
    var value = Number(settings ? settings.refreshIntervalSec : NaN)
    if (!isFinite(value)) return 10
    return Math.max(2, Math.min(600, Math.round(value)))
  }

  // Through a login shell, with the installer's own directory on the PATH:
  // omarchy-shell inherits the session environment, which on a normal install
  // does not carry ~/.local/bin, so running the binary directly finds nothing
  // on a machine where Roundtable works fine. `exec "$@"` keeps the command
  // name a positional parameter, so a path with a space in it stays one
  // argument, and a `command` setting that is an absolute path is unaffected.
  readonly property string invocation: 'PATH="$HOME/.local/bin:$PATH"; exec "$@"'

  function refresh() {
    if (statusProcess.running) return
    statusProcess.command = ["bash", "-lc", root.invocation, "bash", root.command, "status", "--json"]
    statusProcess.running = true
  }

  function clear() {
    running = false
    url = ""
    rooms = []
    roomCount = 0
    participants = 0
    queued = 0
    working = 0
    waiting = 0
  }

  function apply(text) {
    var report = null
    try {
      report = JSON.parse(String(text || ""))
    } catch (e) {
      report = null
    }

    if (!report) {
      clear()
      error = "Could not read the status."
      return
    }

    error = ""
    running = report.running === true
    url = report.url ? String(report.url) : ""

    // `status` is null when the service is up but did not answer in time. Its
    // rooms are unknown, not empty, so the panel says so instead of drawing an
    // empty list.
    var status = report.status
    if (!running || !status || !status.totals) {
      rooms = []
      roomCount = 0
      participants = 0
      queued = 0
      working = 0
      waiting = 0
      if (running && !status) error = "The service is not answering."
      return
    }

    rooms = status.rooms instanceof Array ? status.rooms : []
    roomCount = Number(status.totals.rooms) || 0
    participants = Number(status.totals.participants) || 0
    queued = Number(status.totals.queued) || 0
    working = Number(status.totals.running) || 0
    waiting = Number(status.totals.waiting_for_approval) || 0
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: function (exitCode) {
      root.checked = true

      // 127 is the shell's "no such command": the service is not stopped, it
      // is not installed, and telling the two apart is the difference between
      // "press start" and "go and install it".
      if (exitCode === 127) {
        root.installed = false
        root.clear()
        root.error = ""
        return
      }

      root.installed = true
      root.apply(statusOut.text)
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
