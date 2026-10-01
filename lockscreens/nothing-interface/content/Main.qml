import QtQuick
import QtQuick.Window
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#24262B"
    focus: true

    // Ryoku's in-session SDDM shim exposes fingerprintState; the system greeter
    // does not. Keep Quickshell-only imports in LiveData.qml.
    readonly property bool inSession: typeof sddm !== "undefined"
        && typeof sddm.fingerprintState !== "undefined"
    readonly property var live: liveData.item
    readonly property var battery: live ? live.battery : ({level: -1, charging: false})
    readonly property var activity: live ? live.activity : ({seconds: 0, available: false})
    readonly property var media: live ? live.media : ({available: false, playing: false})
    property date now: new Date()
    property string errorMessage: ""
    readonly property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
        ? sessionModel.lastIndex : 0
    readonly property string loginUser: (typeof userModel !== "undefined" && userModel.lastUser)
        ? userModel.lastUser : ""
    readonly property real uiScale: Math.min(width / 1280, height / 720)

    function duration(seconds) {
        const value = Math.max(0, Math.floor(Number(seconds || 0)))
        return Math.floor(value / 3600) + " ч " + String(Math.floor(value % 3600 / 60)).padStart(2, "0") + " мин"
    }
    function stamp(seconds) {
        const value = Math.max(0, Math.floor(Number(seconds || 0)))
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0")
    }
    function submit() {
        if (!password.text.length || !loginUser.length) return
        errorMessage = ""
        sddm.login(loginUser, password.text, sessionIndex)
    }

    Loader { id: liveData; active: root.inSession; source: "LiveData.qml" }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Timer { id: errorTimer; interval: 3200; onTriggered: root.errorMessage = "" }
    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            password.text = ""
            root.errorMessage = "Неверный пароль"
            errorTimer.restart()
            password.forceActiveFocus()
        }
    }
    Component.onCompleted: password.forceActiveFocus()

    Image {
        anchors.fill: parent
        visible: root.live && root.live.wallpaperUrl.length > 0
        source: root.live ? root.live.wallpaperUrl : ""
        fillMode: root.live && root.live.fit === "Contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    Loader {
        id: videoLayer
        anchors.fill: parent
        active: root.inSession && root.live && root.live.videoUrl.length > 0
        source: "LiveVideo.qml"
        onLoaded: item.sourceUrl = root.live.videoUrl
    }
    Connections {
        target: root.live
        function onVideoUrlChanged() {
            if (videoLayer.item) videoLayer.item.sourceUrl = root.live.videoUrl
        }
    }
    Rectangle { anchors.fill: parent; color: "#550F1013" }

    Item {
        width: 1072
        height: 528
        anchors.centerIn: parent
        scale: root.uiScale

        Text {
            x: 0; y: -43
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            font.family: "Noto Sans"; font.pixelSize: 20
            color: "#F5F5F5"
        }

        // A seven-row dot matrix drawn from vector primitives, no font asset.
        Canvas {
            id: clockDots
            x: 0; y: 28; width: 460; height: 112
            property string digits: Qt.formatTime(root.now, "hh:mm")
            onDigitsChanged: requestPaint()
            onPaint: {
                const glyphs = {
                    "0": ["11111","10001","10011","10101","11001","10001","11111"],
                    "1": ["00100","01100","00100","00100","00100","00100","01110"],
                    "2": ["11111","00001","00001","11111","10000","10000","11111"],
                    "3": ["11111","00001","00001","01111","00001","00001","11111"],
                    "4": ["10001","10001","10001","11111","00001","00001","00001"],
                    "5": ["11111","10000","10000","11111","00001","00001","11111"],
                    "6": ["11111","10000","10000","11111","10001","10001","11111"],
                    "7": ["11111","00001","00010","00100","01000","01000","01000"],
                    "8": ["11111","10001","10001","11111","10001","10001","11111"],
                    "9": ["11111","10001","10001","11111","00001","00001","11111"],
                    ":": ["0","0","1","0","1","0","0"]
                }
                const painter = getContext("2d")
                painter.clearRect(0, 0, width, height)
                const pitch = 14, radius = 4.4
                let column = 0
                for (const digit of digits) {
                    const bitmap = glyphs[digit]
                    if (!bitmap) continue
                    for (let row = 0; row < bitmap.length; row++) {
                        for (let col = 0; col < bitmap[row].length; col++) {
                            if (bitmap[row][col] !== "1") continue
                            painter.beginPath()
                            painter.arc((column + col) * pitch + radius, row * pitch + radius, radius, 0, Math.PI * 2)
                            painter.fillStyle = "#F5F5F5"
                            painter.fill()
                        }
                    }
                    column += bitmap[0].length + (digit === ":" ? 1 : 2)
                }
            }
        }
        Text {
            x: 0; y: 160
            text: "NOTHING INTERFACE"
            font.family: "Noto Sans"; font.pixelSize: 12; font.weight: Font.Medium
            font.letterSpacing: 2.8
            color: "#D6D6DA"
        }

        Rectangle {
            x: 544; y: 0; width: 256; height: 120; radius: 30
            color: "#1C1D21"
            Text {
                x: 22; y: 18
                text: "ЗАРЯД"
                font.family: "Noto Sans"; font.pixelSize: 11; font.letterSpacing: 1.5
                color: "#B1B3B3"
            }
            Text {
                x: 22; y: 47
                text: root.battery.level >= 0 ? root.battery.level + "%" : "—"
                font.family: "Noto Sans"; font.pixelSize: 38; font.weight: Font.Medium
                color: "#F5F5F5"
            }
            Text {
                x: 145; y: 78
                text: root.battery.charging ? "Заряжается" : (root.battery.plugged ? "Подключено" : "От батареи")
                font.family: "Noto Sans"; font.pixelSize: 10
                color: "#B1B3B3"
            }
            Rectangle {
                x: 22; y: 104; width: 212; height: 3; radius: 2; color: "#414247"
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Number(root.battery.level) / 100))
                    height: parent.height; radius: parent.radius; color: "#F5F5F5"
                }
            }
        }

        Rectangle {
            x: 816; y: 0; width: 256; height: 120; radius: 30
            color: "#1C1D21"
            Text {
                x: 22; y: 18
                text: "ВРЕМЯ ЗА ПК"
                font.family: "Noto Sans"; font.pixelSize: 11; font.letterSpacing: 1.5
                color: "#B1B3B3"
            }
            Text {
                x: 22; y: 49
                text: root.activity.available ? root.duration(root.activity.seconds) : "Нет данных"
                font.family: "Noto Sans"; font.pixelSize: 25; font.weight: Font.Medium
                color: "#F5F5F5"
            }
            Text {
                x: 22; y: 96
                text: "Сегодня · Ryoku Rashin"
                font.family: "Noto Sans"; font.pixelSize: 11
                color: "#B1B3B3"
            }
        }

        Rectangle {
            x: 544; y: 136; width: 528; height: 256; radius: 30
            color: "#1C1D21"
            Text {
                x: 24; y: 19
                text: "СЕЙЧАС ИГРАЕТ"
                font.family: "Noto Sans"; font.pixelSize: 11; font.letterSpacing: 1.5
                color: "#B1B3B3"
            }
            Text {
                x: 148; y: 57; width: 356
                text: root.media.available ? (root.media.title || "Музыка") : "Ничего не играет"
                font.family: "Noto Sans"; font.pixelSize: 26; font.weight: Font.Medium
                color: "#F5F5F5"; elide: Text.ElideRight
            }
            Text {
                x: 148; y: 104; width: 356
                text: root.media.available ? (root.media.artist || " ") : "Запустите музыку на рабочем столе"
                font.family: "Noto Sans"; font.pixelSize: 15
                color: "#B1B3B3"; elide: Text.ElideRight
            }
            Rectangle {
                x: 24; y: 56; width: 104; height: 104; radius: 52
                color: "#303136"; border.color: "#515258"; border.width: 1
            }
            Image {
                x: 24; y: 56; width: 104; height: 104
                source: root.media.available ? String(root.media.artUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
            }
            Rectangle {
                x: 24; y: 174; width: 480; height: 3; radius: 2; color: "#414247"
                Rectangle {
                    width: parent.width * (Number(root.media.length) > 0
                        ? Math.max(0, Math.min(1, Number(root.media.position) / Number(root.media.length))) : 0)
                    height: parent.height; radius: parent.radius; color: "#F5F5F5"
                }
            }
            Text {
                x: 24; y: 188
                text: root.stamp(root.media.position) + " / " + root.stamp(root.media.length)
                font.family: "Noto Sans"; font.pixelSize: 11; color: "#B1B3B3"
            }
            Rectangle {
                x: 451; y: 190; width: 54; height: 54; radius: 27
                color: "#303136"; opacity: root.media.available ? 1 : 0.5
                Text {
                    anchors.centerIn: parent
                    text: root.media.playing ? "Ⅱ" : "▶"
                    font.family: "Noto Sans"; font.pixelSize: 24; color: "#F5F5F5"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.live) root.live.togglePlayback()
                }
            }
        }

        Rectangle {
            x: 0; y: 364; width: 440; height: 164; radius: 30
            color: "#1C1D21"
            Text {
                x: 24; y: 16
                text: root.loginUser.length ? root.loginUser : "Пользователь"
                font.family: "Noto Sans"; font.pixelSize: 14; font.weight: Font.Medium
                color: "#F5F5F5"
            }
            Rectangle {
                x: 24; y: 50; width: 392; height: 52; radius: 26
                color: "#303136"
                border.color: password.activeFocus ? "#77787D" : "#44454A"
                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 20; anchors.rightMargin: 20
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.family: "Noto Sans"; font.pixelSize: 18
                    color: "#F5F5F5"
                    verticalAlignment: TextInput.AlignVCenter
                    onAccepted: root.submit()
                }
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    verticalAlignment: Text.AlignVCenter
                    visible: password.text.length === 0
                    text: "Пароль"
                    font.family: "Noto Sans"; font.pixelSize: 15
                    color: "#A9AAAE"
                    MouseArea { anchors.fill: parent; onClicked: password.forceActiveFocus() }
                }
            }
            Text {
                x: 24; y: 112
                text: root.errorMessage.length ? root.errorMessage : "Нажмите Enter, чтобы разблокировать"
                font.family: "Noto Sans"; font.pixelSize: 12
                color: root.errorMessage.length ? "#D84545" : "#B1B3B3"
            }
            Rectangle {
                x: 369; y: 108; width: 47; height: 43; radius: 21
                color: "#F5F5F5"
                Text {
                    anchors.centerIn: parent
                    text: "→"; font.family: "Noto Sans"; font.pixelSize: 22
                    color: "#1C1D21"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submit()
                }
            }
        }
    }
}
