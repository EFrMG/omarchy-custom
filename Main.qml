import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 1024
  height: 640
  color: "#1a1b26"

  property bool loginFailed: false
  property bool userExpanded: false
  property bool sessionExpanded: false

  function doLogin() {
    var user = nameField.text
    var idx = sessionList.currentIndex >= 0 ? sessionList.currentIndex : sessionModel.lastIndex
    if (user === "") {
      root.loginFailed = true
      nameField.focus = true
      return
    }
    sddm.login(user, password.text, idx)
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

  // --- Center: omarchy login ---
  Column {
    id: loginColumn
    anchors.centerIn: parent
    spacing: 20

    Image {
      id: logo
      source: "logo.png"
      width: 280
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: nameField.text + " @ " + (sessionList.currentItem ? sessionList.currentItem.sessionName : "")
      color: "#565f89"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 14
    }

    // Editable username: works even if the user model is slow/empty.
    TextBox {
      id: nameField
      anchors.horizontalCenter: parent.horizontalCenter
      width: entry.width
      height: 30
      text: userModel.lastUser
      font.pixelSize: 14
      Keys.onPressed: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          doLogin()
          event.accepted = true
        }
      }
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

    // Picker buttons: users and sessions live behind dropdowns.
    Row {
      id: pickerRow
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 12

      Rectangle {
        id: userButton
        width: 170
        height: 34
        radius: 6
        color: root.userExpanded ? "#334155" : "#24283b"
        Text {
          anchors.centerIn: parent
          text: (nameField.text !== "" ? nameField.text : "user") + " \u25BE"
          color: "#c0caf5"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
          elide: Text.ElideRight
          width: parent.width - 20
          horizontalAlignment: Text.AlignHCenter
        }
        MouseArea {
          anchors.fill: parent
          onClicked: {
            root.userExpanded = !root.userExpanded
            root.sessionExpanded = false
          }
        }
      }

      Rectangle {
        id: sessionButton
        width: 170
        height: 34
        radius: 6
        color: root.sessionExpanded ? "#334155" : "#24283b"
        Text {
          anchors.centerIn: parent
          text: (sessionList.currentItem ? sessionList.currentItem.sessionName : "session") + " \u25BE"
          color: "#c0caf5"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 14
          elide: Text.ElideRight
          width: parent.width - 20
          horizontalAlignment: Text.AlignHCenter
        }
        MouseArea {
          anchors.fill: parent
          onClicked: {
            root.sessionExpanded = !root.sessionExpanded
            root.userExpanded = false
          }
        }
      }
    }
  }

  // NOTE: SDDM userModel roles are name/realName/icon — NOT Qt.DisplayRole,
  // so delegates must use model.name (model.display is empty).
  Rectangle {
    id: userDropdown
    visible: root.userExpanded
    width: 250
    height: Math.min(userList.contentHeight + 62, 270)
    color: "#24283b"
    radius: 8
    z: 10
    anchors.top: pickerRow.bottom
    anchors.topMargin: 8
    anchors.horizontalCenter: userButton.horizontalCenter

    Column {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 8
      Text {
        text: "users"
        color: "#7aa2f7"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
      }
      ListView {
        id: userList
        width: parent.width
        height: parent.height - 30
        clip: true
        model: userModel
        spacing: 4
        delegate: Rectangle {
          property string userName: (model.name !== undefined && model.name !== "") ? model.name : model.display
          width: userList.width
          height: 32
          radius: 6
          color: userList.currentIndex === index ? "#334155" : "transparent"
          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: (model.realName !== undefined && model.realName !== "") ? model.realName : parent.userName
            color: userList.currentIndex === index ? "#ffffff" : "#c0caf5"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            elide: Text.ElideRight
            width: parent.width - 20
          }
          MouseArea {
            anchors.fill: parent
            onClicked: {
              userList.currentIndex = index
              nameField.text = parent.userName
              root.loginFailed = false
              root.userExpanded = false
              password.focus = true
            }
          }
        }
      }
    }
  }

  Rectangle {
    id: sessionDropdown
    visible: root.sessionExpanded
    width: 250
    height: Math.min(sessionList.contentHeight + 62, 270)
    color: "#24283b"
    radius: 8
    z: 10
    anchors.top: pickerRow.bottom
    anchors.topMargin: 8
    anchors.horizontalCenter: sessionButton.horizontalCenter

    Column {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 8
      Text {
        text: "sessions"
        color: "#7aa2f7"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
      }
      ListView {
        id: sessionList
        width: parent.width
        height: parent.height - 30
        clip: true
        model: sessionModel
        currentIndex: sessionModel.lastIndex
        spacing: 4
        delegate: Rectangle {
          property string sessionName: (model.name !== undefined && model.name !== "") ? model.name : model.display
          width: sessionList.width
          height: 32
          radius: 6
          color: sessionList.currentIndex === index ? "#334155" : "transparent"
          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: parent.sessionName
            color: sessionList.currentIndex === index ? "#ffffff" : "#c0caf5"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            elide: Text.ElideRight
            width: parent.width - 20
          }
          MouseArea {
            anchors.fill: parent
            onClicked: {
              sessionList.currentIndex = index
              root.sessionExpanded = false
              password.focus = true
            }
          }
        }
      }
    }
  }

  Component.onCompleted: {
    password.forceActiveFocus()
  }
}
