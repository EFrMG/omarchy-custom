import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 1024
  height: 640
  color: "#1a1b26"

  property bool loginFailed: false
  property bool userPicked: false
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
      userCombo.forceActiveFocus()
      return
    }
    sddm.login(selectedName, password.text, sessionCombo.index)
  }

  function cycleIndex(combo, count, delta) {
    if (count <= 0) {
      return
    }
    var i = combo.index + delta
    if (i < 0) {
      i = count - 1
    } else if (i >= count) {
      i = 0
    }
    combo.index = i
  }

  function focusNext() {
    if (password.activeFocus) {
      userCombo.forceActiveFocus()
    } else if (userCombo.activeFocus) {
      sessionCombo.forceActiveFocus()
    } else {
      password.forceActiveFocus()
    }
  }

  function focusPrev() {
    if (password.activeFocus) {
      sessionCombo.forceActiveFocus()
    } else if (sessionCombo.activeFocus) {
      userCombo.forceActiveFocus()
    } else {
      password.forceActiveFocus()
    }
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.forceActiveFocus()
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

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
            userPickModel.append({ "display": userName, "name": userName, "label": userLabel })
          }
        }
      }
    }
  }

  Component {
    id: userRow
    Text {
      anchors.fill: parent
      anchors.margins: 5
      verticalAlignment: Text.AlignVCentered
      color: "#c0caf5"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 14
      elide: Text.ElideRight
      text: parent.modelItem.label
    }
  }

  // Unused (kept for reference): SDDM ComboBox only honors rowDelegate.
  Component {
    id: userTopRow
    Text {
      anchors.fill: parent
      anchors.margins: 5
      verticalAlignment: Text.AlignVCentered
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
      width: 700
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

        // Focus ring so you can tell the password box is active.
        Rectangle {
          id: passwordRing
          anchors.fill: parent
          anchors.margins: -4
          color: "transparent"
          radius: 8
          border.width: 2
          border.color: root.loginFailed ? "#f7768e" : (password.activeFocus ? "#7aa2f7" : "transparent")
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
          verticalAlignment: TextInput.AlignVCentered
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "\u2022"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          activeFocusOnPress: true
          cursorVisible: true
          cursorDelegate: Rectangle {
            width: 2
            height: 22
            color: "#7aa2f7"
            visible: password.activeFocus
          }
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              doLogin()
              event.accepted = true
            } else if (event.key === Qt.Key_Tab) {
              if (event.modifiers & Qt.ShiftModifier) {
                focusPrev()
              } else {
                focusNext()
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              userCombo.forceActiveFocus()
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              sessionCombo.forceActiveFocus()
              event.accepted = true
            }
          }
        }
      }
    }

    Row {
      id: pickerRow
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 12

      Item {
        width: 220
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
          // NOTE: SDDM ComboBox already handles Up/Down internally on
          // Keys.onPressed (moves highlight). Our outer handler would
          // swallow it if we accept on Pressed, so: cycle the committed
          // index on Pressed (works open AND closed, highlight follows
          // via onIndexChanged), and do Enter-login on Released so an
          // open dropdown commits first (inner close(true) on Pressed).
          Keys.onPressed: {
            if (event.key === Qt.Key_Tab) {
              if (event.modifiers & Qt.ShiftModifier) {
                focusPrev()
              } else {
                focusNext()
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Space) {
              userCombo.toggle()
              event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              cycleIndex(userCombo, userPickModel.count, 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              cycleIndex(userCombo, userPickModel.count, -1)
              event.accepted = true
            }
          }
          Keys.onReleased: {
            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
              doLogin()
              event.accepted = true
            }
          }
        }
      }

      Item {
        width: 220
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
          // Same Up/Down + Enter rationale as userCombo above:
          // cycle committed index on Pressed, login on Released.
          Keys.onPressed: {
            if (event.key === Qt.Key_Tab) {
              if (event.modifiers & Qt.ShiftModifier) {
                focusPrev()
              } else {
                focusNext()
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Space) {
              sessionCombo.toggle()
              event.accepted = true
            } else if (event.key === Qt.Key_Down) {
              cycleIndex(sessionCombo, sessionModel.count, 1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              cycleIndex(sessionCombo, sessionModel.count, -1)
              event.accepted = true
            }
          }
          Keys.onReleased: {
            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
              doLogin()
              event.accepted = true
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    selectLastUser()
    password.forceActiveFocus()
  }
}