import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root
    implicitWidth: 280
    implicitHeight: 150

    // Crypto State
    property string activeCoin: "bitcoin" // "bitcoin", "ethereum", "solana"
    property var cryptoData: ({
        bitcoin: { symbol: "BTC", name: "Bitcoin", price: 79110, change: 1.44, color: "#FFE082" },
        ethereum: { symbol: "ETH", name: "Ethereum", price: 2521, change: 2.96, color: "#C2E7FF" },
        solana: { symbol: "SOL", name: "Solana", price: 106.5, change: 1.42, color: "#D7AEFB" }
    })
    property var sparklines: ({
        bitcoin: [62, 65, 63, 68, 72, 70, 75, 74, 79],
        ethereum: [23, 24, 23.5, 24.8, 25.1, 24.9, 25.2],
        solana: [98, 101, 99, 104, 103, 106, 106.5]
    })

    // Process to query CoinGecko API
    Process {
        id: priceProc
        command: ["sh", "-c", "curl -s --max-time 4 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,solana&vs_currencies=usd&include_24hr_change=true' 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    var cData = Object.assign({}, root.cryptoData)
                    if (data.bitcoin && data.bitcoin.usd) {
                        cData.bitcoin.price = data.bitcoin.usd
                        cData.bitcoin.change = data.bitcoin.usd_24h_change || 0
                    }
                    if (data.ethereum && data.ethereum.usd) {
                        cData.ethereum.price = data.ethereum.usd
                        cData.ethereum.change = data.ethereum.usd_24h_change || 0
                    }
                    if (data.solana && data.solana.usd) {
                        cData.solana.price = data.solana.usd
                        cData.solana.change = data.solana.usd_24h_change || 0
                    }
                    root.cryptoData = cData
                    trendCanvas.requestPaint()
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 60000 // Refresh every 1 min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: priceProc.running = true
    }


    // Theme Palette
    readonly property color colBg: Theme.colBg
    readonly property color colBadgeBg: Theme.colPillBg
    readonly property color colPositive: Theme.colAccentGreen
    readonly property color colNegative: Theme.colAccentWarm
    readonly property color colTextPrimary: Theme.colTextPrimary
    readonly property color colTextSecondary: Theme.colTextSecondary

    property var currentCoinInfo: root.cryptoData[root.activeCoin] || root.cryptoData.bitcoin

    // ─── Scaled Visual Content ───
    Item {
        id: scaledContent
        width: 280
        height: 150
        transformOrigin: Item.TopLeft

        // Main Card
        Rectangle {
            anchors.fill: parent
            color: root.colBg
            radius: 32
            border.color: Theme.borderColor
            border.width: Theme.borderWidth
            clip: true
            antialiasing: true

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1.5
                color: Theme.glassGloss
                visible: Theme.isGlass
            }

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                // Header Row: MARKETS Pill Badge + Coin Switcher
                Row {
                    width: parent.width

                    Rectangle {
                        height: 22
                        width: badgeRow.implicitWidth + 16
                        radius: 11
                        color: root.colBadgeBg
                        antialiasing: true

                        Row {
                            id: badgeRow
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 7
                                radius: 3.5
                                color: root.currentCoinInfo.color
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "MARKETS"
                                color: root.colTextPrimary
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 0.6
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    Item {
                        width: Math.max(0, parent.width - parent.children[0].width - coinsRow.width)
                        height: 1
                    }

                    // Coin Selector Pills (BTC / ETH / SOL)
                    Row {
                        id: coinsRow
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: ["bitcoin", "ethereum", "solana"]

                            Rectangle {
                                width: 34
                                height: 20
                                radius: 10
                                color: (root.activeCoin === modelData) ? root.cryptoData[modelData].color : root.colBadgeBg
                                antialiasing: true

                                Text {
                                    anchors.centerIn: parent
                                    text: root.cryptoData[modelData].symbol
                                    color: (root.activeCoin === modelData) ? "#1E2A30" : root.colTextSecondary
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.activeCoin = modelData
                                        trendCanvas.requestPaint()
                                    }
                                }
                            }
                        }
                    }
                }

                // Middle Big Price + 24h Change Pill + Sparkline
                Row {
                    width: parent.width
                    spacing: 10

                    Column {
                        width: 140
                        spacing: 2

                        Text {
                            text: "$" + Number(root.currentCoinInfo.price).toLocaleString(Qt.locale(), "f", (root.currentCoinInfo.price > 100 ? 0 : 2))
                            color: root.colTextPrimary
                            font.pixelSize: 22
                            font.bold: true
                            font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                        }

                        Row {
                            spacing: 6

                            // 24h Change Badge Pill
                            Rectangle {
                                height: 18
                                width: chgText.implicitWidth + 12
                                radius: 9
                                color: (root.currentCoinInfo.change >= 0) ? "#20A2C9C2" : "#20FFB4AB"
                                antialiasing: true

                                Text {
                                    id: chgText
                                    anchors.centerIn: parent
                                    text: (root.currentCoinInfo.change >= 0 ? "+" : "") + root.currentCoinInfo.change.toFixed(2) + "%"
                                    color: (root.currentCoinInfo.change >= 0) ? root.colPositive : root.colNegative
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.family: "Google Sans Flex, Google Sans, Inter, monospace"
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.currentCoinInfo.name
                                color: root.colTextSecondary
                                font.pixelSize: 10
                                font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                            }
                        }
                    }

                    // Mini Sparkline Canvas
                    Canvas {
                        id: trendCanvas
                        width: parent.width - 140 - 10
                        height: 48
                        anchors.verticalCenter: parent.verticalCenter
                        antialiasing: true

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var pts = root.sparklines[root.activeCoin] || [10, 20, 15, 30]
                            if (pts.length < 2) return

                            var minVal = Math.min(...pts)
                            var maxVal = Math.max(...pts)
                            var range = maxVal - minVal || 1
                            var step = width / (pts.length - 1)

                            ctx.strokeStyle = (root.currentCoinInfo.change >= 0) ? root.colPositive : root.colNegative
                            ctx.lineWidth = 2
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"

                            ctx.beginPath()
                            for (var i = 0; i < pts.length; i++) {
                                var x = i * step
                                var norm = (pts[i] - minVal) / range
                                var y = height - (norm * (height - 8)) - 4
                                if (i === 0) ctx.moveTo(x, y)
                                else ctx.lineTo(x, y)
                            }
                            ctx.stroke()
                        }
                    }
                }

                // Bottom 24h Volume / Status
                Text {
                    text: "24h Live Market Tracking · CoinGecko"
                    color: root.colTextSecondary
                    font.pixelSize: 9
                    font.family: "Google Sans Flex, Google Sans, Inter, sans-serif"
                }
            }
        }
    }
}
