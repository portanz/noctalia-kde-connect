pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Singleton {
  id: root

  property list<var> devices: []
  property bool daemonAvailable: false
  property int pendingDeviceCount: 0
  property list<var> pendingDevices: []

  property var mainDevice: null

  onDevicesChanged: {
    var newMain = devices.length === 0 ? null : devices[0];
    if (mainDevice !== newMain) {
      root.mainDevice = newMain;
    }
  }

  reloadableId: "kdeconnect"

  Component.onCompleted: {
    checkDaemon();
  }

  // Check if KDE Connect daemon is available
  function checkDaemon(): void {
    daemonCheckProc.running = true;
  }

  // Refresh the list of devices
  function refreshDevices(): void {
    getDevicesProc.running = true;
  }

  // Send a ping to a device
  function pingDevice(deviceId: string): void {
    const proc = pingComponent.createObject(root, { deviceId: deviceId });
    proc.running = true;
  }

  function triggerFindMyPhone(deviceId: string): void {
    const proc = findMyPhoneComponent.createObject(root, { deviceId: deviceId });
    proc.running = true;
  }

  // Share a file with a device
  function shareFile(deviceId: string, filePath: string): void {
    var proc = shareComponent.createObject(root, {
      deviceId: deviceId,
      filePath: filePath
    });
    proc.running = true;
  }

  // Check daemon
  Process {
    id: daemonCheckProc
    command: ["qdbus", "org.kde.kdeconnect"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.daemonAvailable = text.trim().length > 0;
        Logger.i("KDEConnect", "Daemon available:", root.daemonAvailable);
        if (root.daemonAvailable) {
          root.refreshDevices();
        }
      }
    }
  }

  // Get device list
  Process {
    id: getDevicesProc
    command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect", "org.kde.kdeconnect.daemon.devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        const deviceIds = text.trim().split('\n').filter(id => id.length > 0);

        root.pendingDevices = [];
        root.pendingDeviceCount = deviceIds.length;

        deviceIds.forEach(deviceId => {
          const loader = deviceLoaderComponent.createObject(root, { deviceId: deviceId });
          loader.start();
        });
      }
    }
  }

  // Component that loads all info for a single device
  Component {
    id: deviceLoaderComponent

    QtObject {
      id: loader
      property string deviceId: ""
      property var deviceData: ({
        id: deviceId,
        name: "",
        reachable: false,
        paired: false,
        charging: false,
        battery: -1,
        cellularNetworkType: "",
        cellularNetworkStrength: -1
      })

      function start() {
        nameProc.running = true;
      }

      property Process nameProc: Process {
        command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device.name"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.name = text.trim();
            reachableProc.running = true;
          }
        }
      }

      property Process reachableProc: Process {
        command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device.isReachable"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.reachable = text.trim() === "true";

            if (loader.deviceData.reachable)
              pairedProc.running = true;
            else
              finalize()
          }
        }
      }

      property Process pairedProc: Process {
        command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId, "org.kde.kdeconnect.device.isPaired"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.paired = text.trim() === "true";

            if (loader.deviceData.paired)
              cellularNetworkTypeProc.running = true;
            else
              finalize()
          }
        }
      }

      property Process cellularNetworkTypeProc: Process {
        command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.freedesktop.DBus.Properties.Get", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkType"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.cellularNetworkType = text.trim();
            cellularNetworkStrengthProc.running = true;
          }
        }
      }

      property Process cellularNetworkStrengthProc: Process {
        command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId + "/connectivity_report", "org.freedesktop.DBus.Properties.Get", "org.kde.kdeconnect.device.connectivity_report", "cellularNetworkStrength"]
        stdout: StdioCollector {
          onStreamFinished: {
            const strength = parseInt(text.trim());
            if (!isNaN(strength)) {
              loader.deviceData.cellularNetworkStrength = strength;
            }
            isChargingProc.running = true;
          }
        }
      }

      property Process isChargingProc: Process {
        command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.freedesktop.DBus.Properties.Get", "org.kde.kdeconnect.device.battery", "isCharging"]
        stdout: StdioCollector {
          onStreamFinished: {
            loader.deviceData.charging = text.trim() === "true";
            batteryProc.running = true;
          }
        }
      }

      property Process batteryProc: Process {
        command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + loader.deviceId + "/battery", "org.freedesktop.DBus.Properties.Get", "org.kde.kdeconnect.device.battery", "charge"]
        stdout: StdioCollector {
          onStreamFinished: {
            const charge = parseInt(text.trim());
            if (!isNaN(charge)) {
              loader.deviceData.battery = charge;
            }

            finalize();
          }
        }
      }

      function finalize() {
        root.pendingDevices = root.pendingDevices.concat([loader.deviceData]);

        if (root.pendingDevices.length === root.pendingDeviceCount) {
          root.devices = root.pendingDevices
          root.pendingDevices = []
        }

        loader.destroy();
      }
    }
  }

  // Ping component
  Component {
    id: pingComponent
    Process {
      id: proc
      property string deviceId: ""
      command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device.sendPing"]
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // FindMyPhone component
  Component {
    id: findMyPhoneComponent
    Process {
      id: proc
      property string deviceId: ""
      command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId + "/findmyphone", "org.kde.kdeconnect.device.findmyphone.ring"]
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // Share file component
  Component {
    id: shareComponent
    Process {
      id: proc
      property string deviceId: ""
      property string filePath: ""
      command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + deviceId, "org.kde.kdeconnect.device.shareUrl", "file://" + filePath]
      stdout: StdioCollector {
        onStreamFinished: proc.destroy()
      }
    }
  }

  // Periodic refresh timer
  Timer {
    interval: 5000
    running: root.daemonAvailable
    repeat: true
    onTriggered: root.refreshDevices()
  }
}