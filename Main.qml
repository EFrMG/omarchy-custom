import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 1024
  height: 640
  color: "#1a1b26"

  property bool loginFailed: false
  property bool userPicked: false
  // Login name comes only from the users dropdown (no username text field).
  // QML cannot index a QAbstractListModel, so userModel is mirrored into a
  // plain ListModel once at startup and read back with get(index).
  property string selectedName: (userCombo.index >= 0 && userCombo.index < userPickModel.count) ? userPickModel.get(userCombo.index).name : ""

  function selectLastUser() {
    if (userPicked || userPickModel.count === 0) {
      return
    }
    for (var i = 0; i < userPickModel.count; i++) {
      if (userPickModel.get(i).name === userModel.lastUser) {
        userCombo.index = i
        return
      }
    }
    userCombo.index = 0
  }

  function doLogin() {
    if (selectedName === "") {
      root.loginFailed = true
      userCombo.focus = true
      return
    }
    sddm.login(selectedName, password.text, sessionCombo.index)
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  // NOTE: SDDM userModel roles are name/realName/icon — NOT Qt.DisplayRole,
  // so delegates must use model.name (model.display is empty).
  ListModel {
    id: userPickModel
    onCountChanged: selectLastUser()
  }

  Item {
    Repeater {
      model: userModel
      delegate: Item {
        property string userName: (model.name !== undefined && model.name !== "") ? model.name : model.display
        property string userLabel: (model.realName !== undefined && model.realName !== "") ? model.realName : userName
        Component.onCompleted: {
          if (userName !== undefined && userName !== "") {
            userPickModel.append({ "name": userName, "label": userLabel })
          }
        }
      }
    }
  }

  // Row delegate shared by the users ComboBox top row and its popup rows.
  // parent is the ComboBox internal Loader, which carries modelItem.
  Component {
    id: userRow
    Text {
      anchors.fill: parent
      anchors.margins: 5
      verticalAlignment: Text.AlignVCenter
      color: "#c0caf5"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 14
      elide: Text.ElideRight
      text: parent.modelItem.label
    }
  }

  // --- Center: omarchy login ---
  Column {
    id: loginColumn
    anchors.centerIn: parent
    spacing: 20

    Image {
      id: logo
      source: "logo.png"
      width: 400
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15

      Image {
        source: root.loginFailed ? "lock-failed.png" : "lock.png"
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.loginFailed ? "entry-failed.png" : "entry.png"
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "\u2022"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              doLogin()
              event.accepted = true
            }
          }
        }
      }
    }

    // Native SDDM ComboBoxes, like elarun/maldives/maya use: each opens its
    // list immediately underneath itself. The overlay chevron is purely
    // visual (no MouseArea), so clicks pass through to the ComboBox.
    Row {
      id: pickerRow
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 12

      Item {
        width: 170
        height: 34

        ComboBox {
          id: userCombo
          anchors.fill: parent
          model: userPickModel
          color: "#24283b"
          borderColor: "#334155"
          borderWidth: 1
          focusColor: "#7aa2f7"
          hoverColor: "#334155"
          textColor: "#c0caf5"
          menuColor: "#24283b"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
          rowDelegate: userRow
          onValueChanged: root.userPicked = true
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: "\u25BC"
          color: "#7aa2f7"
          font.pixelSize: 12
        }
      }

      Item {
        width: 170
        height: 34

        ComboBox {
          id: sessionCombo
          anchors.fill: parent
          model: sessionModel
          index: sessionModel.lastIndex
          color: "#24283b"
          borderColor: "#334155"
          borderWidth: 1
          focusColor: "#7aa2f7"
          hoverColor: "#334155"
          textColor: "#c0caf5"
          menuColor: "#24283b"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
        }

        Text {
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: "\u25BC"
          color: "#7aa2f7"
          font.pixelSize: 12
        }
      }
    }
  }

  Component.onCompleted: {
    selectLastUser()
    password.forceActiveFocus()
  }
}
