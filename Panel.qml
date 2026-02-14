import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "./Services"
import Quickshell

// Panel Component
Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null

  // SmartPanel
  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 440 * Style.uiScaleRatio
  property real contentPreferredHeight: 360 * Style.uiScaleRatio

  readonly property bool allowAttach: true

  anchors.fill: parent

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("KDEConnect", "Panel initialized");
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: deviceData

      function getBatteryIcon(percentage, isCharging) {
        if (isCharging) return "battery-charging"
        if (percentage < 5) return "battery"
        if (percentage < 25) return "battery-1"
        if (percentage < 50) return "battery-2"
        if (percentage < 75) return "battery-3"
        return "battery-4"
      }

      function getCellularTypeIcon(type) {
        switch (type) {
          case "5G": return "signal-5g"
          case "LTE": return "signal-4g"
          case "HSPA": return "signal-h"
          case "UMTS": return "signal-3g"
          case "EDGE": return "signal-e"
          case "GPRS": return "signal-g"
          case "GSM": return "signal-2g"
          case "CDMA": return "signal-3g"
          case "CDMA2000": return "signal-3g"
          case "iDEN": return "signal-2g"
          default: return "wave-square"
        }
      }

      function getCellularStrengthIcon(strength) {
        switch (strength) {
          case 0: return "antenna-bars-1"
          case 1: return "antenna-bars-2"
          case 2: return "antenna-bars-3"
          case 3: return "antenna-bars-4"
          case 4: return "antenna-bars-5"
          default: return "antenna-bars-off"
        }
      }

      function getSignalStrengthText(strength) {
        switch (strength) {
          case 0: return "Very Weak"
          case 1: return "Weak"
          case 2: return "Fair"
          case 3: return "Good"
          case 4: return "Excellent"
          default: return "Unknown"
        }
      }

      anchors {
        fill: parent
        margins: Style.marginL
      }
      spacing: Style.marginL

      // HEADER
      NBox {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + (Style.marginXL)

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NIcon {
            icon: "device-mobile"
            pointSize: Style.fontSizeXXL
            color: Color.mPrimary
          }

          NText {
            text: "Connected Devices"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
            color: Color.mOnSurface
            Layout.fillWidth: true
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              root.close();
            }
          }
        }
      }

      // DEVICE CARD
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusM

        ColumnLayout {
          anchors {
            fill: parent
            margins: Style.marginL
          }
          spacing: Style.marginL

          // Device Name

          RowLayout {
            NText {
              text: KDEConnect.mainDevice === null ? "No device connected" : KDEConnect.mainDevice.name
              pointSize: Style.fontSizeXXL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NFilePicker {
              id: shareFilePicker
              title: "Pick file to send"
              selectionMode: "files"
              initialPath: Quickshell.env("HOME")
              nameFilters: ["*"]
              onAccepted: paths => {
                if (paths.length > 0) {
                  for (const path of paths) {
                    KDEConnect.shareFile(KDEConnect.mainDevice.id, path)
                  }
                }
              }
            }

            NIconButton {
              icon: "device-mobile-share"
              tooltipText: "Send File"
              onClicked: {
                shareFilePicker.open()
              }
            }

            NIconButton {
              icon: "radar"
              tooltipText: "Find my Device"
              onClicked: {
                KDEConnect.triggerFindMyPhone(KDEConnect.mainDevice.id)
              }
            }
          }

          // Device Status
          Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            active: KDEConnect.mainDevice !== null
            sourceComponent: deviceStatsWithPhone
          }

        }

        Component {
          id: deviceStatsWithPhone

          RowLayout {

            Rectangle {
              width: 100
              color: "transparent"
              Layout.fillHeight: true
              Layout.leftMargin: Style.marginL

              PhoneDisplay {
                Layout.alignment: Qt.AlignTop
                backgroundImage: ""
              }
            }

            // Stats Grid
            GridLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignTop
              columns: 1
              rowSpacing: Style.marginL

              // Battery Section
              RowLayout {
                spacing: Style.marginM

                NIcon {
                  icon: deviceData.getBatteryIcon(KDEConnect.mainDevice.battery, KDEConnect.mainDevice.charging)
                  pointSize: Style.fontSizeXXL
                  applyUiScale: true
                  color: KDEConnect.mainDevice.charging ? Color.mPrimary : Color.mOnSurface
                }

                ColumnLayout {
                  spacing: 2

                  NText {
                    text: "Battery"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                  }

                  NText {
                    text: KDEConnect.mainDevice.battery + "%"
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightMedium
                    color: Color.mOnSurface
                  }
                }
              }

              // Network Type Section
              RowLayout {
                spacing: Style.marginM

                NIcon {
                  icon: deviceData.getCellularTypeIcon(KDEConnect.mainDevice.cellularNetworkType)
                  pointSize: Style.fontSizeXXL
                  applyUiScale: true
                  color: Color.mOnSurface
                }

                ColumnLayout {
                  spacing: 2

                  NText {
                    text: "Network"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                  }

                  NText {
                    text: KDEConnect.mainDevice.cellularNetworkType
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightMedium
                    color: Color.mOnSurface
                  }
                }
              }

              // Signal Strength Section
              RowLayout {
                spacing: Style.marginM

                NIcon {
                  icon: deviceData.getCellularStrengthIcon(KDEConnect.mainDevice.cellularNetworkStrength)
                  pointSize: Style.fontSizeXXL
                  applyUiScale: true
                  color: Color.mOnSurface
                }

                ColumnLayout {
                  spacing: 2

                  NText {
                    text: "Signal Strength"
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                  }

                  NText {
                    text: deviceData.getSignalStrengthText(KDEConnect.mainDevice.cellularNetworkStrength)
                    pointSize: Style.fontSizeL
                    font.weight: Style.fontWeightMedium
                    color: Color.mOnSurface
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
