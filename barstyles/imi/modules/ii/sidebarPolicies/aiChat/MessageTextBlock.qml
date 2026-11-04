pragma ComponentBehavior: Bound

import "../../../.."
import "../../../../services"
import "../../../common"
import "../../../common/widgets"
import "../../../common/functions"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    property bool editing: false
    property bool renderMarkdown: true
    property bool enableMouseSelection: false
    property var segmentContent: ({})
    property var messageData: {}
    property bool done: true
    property bool forceDisableChunkSplitting: false

    property list<string> renderedLatexHashes: []
    property string renderedSegmentContent: ""
    property string shownText: ""
    property bool fadeChunkSplitting: !forceDisableChunkSplitting && !editing && !/\n\|/.test(shownText) && Config.options.sidebar.ai.textFadeIn

    Layout.fillWidth: true

    function fitLocalImages(s, width) {
        if (width <= 0) return s;
        return String(s).replace(
            /!\[([^\]]*)\]\((\/[^)\s]*\/(?:inline-|gen-)[^)\s]+)\)/g,
            (m, alt, path) => `<img src="${path}" width="${Math.max(64, Math.floor(width - 8))}"/>`);
    }

    Timer {
        id: renderTimer
        interval: 1000
        repeat: false
        onTriggered: {
            renderLatex()
            for (const hash of renderedLatexHashes) {
                handleRenderedLatex(hash, true);
            }
        }
    }

    function renderLatex() {
        let regex = /(\$\$([\s\S]+?)\$\$)|(\$([^\$]+?)\$)|(\\\[((?:.|\n)+?)\\\])|(\\\(([\s\S]+?)\\\))/g;
        let match;
        while ((match = regex.exec(segmentContent)) !== null) {
            let expression = match[1] || match[2] || match[3] || match[4] || match[5] || match[6] || match[7] || match[8];
            if (expression) {
                Qt.callLater(() => {
                    const [renderHash, isNew] = LatexRenderer.requestRender(expression.trim());
                    if (!renderedLatexHashes.includes(renderHash)) {
                        renderedLatexHashes.push(renderHash);
                    }
                });
            }
        }
    }

    function handleRenderedLatex(hash, force = false) {
        if (renderedLatexHashes.includes(hash) || force) {
            const imagePath = LatexRenderer.renderedImagePaths[hash];
            const markdownImage = `![latex](${imagePath})`;

            const expression = LatexRenderer.processedExpressions[hash];
            renderedSegmentContent = renderedSegmentContent.replace(expression, markdownImage);
        }
    }

    onDoneChanged: {
        renderTimer.restart();
    }
    onEditingChanged: {
        if (!editing) {
            renderedSegmentContent = segmentContent;
            root.shownText = segmentContent;
            renderLatex()
        } else {
            root.shownText = segmentContent
        }
    }

    onSegmentContentChanged: {
        if (root.editing) return;
        renderedSegmentContent = segmentContent;
        if (segmentContent) {
            root.renderLatex();
        }
    }

    onRenderedSegmentContentChanged: {
        if (root.editing) return;
        if (renderedSegmentContent) {
            root.shownText = renderedSegmentContent;
        }
    }

    Connections {
        target: LatexRenderer
        function onRenderFinished(hash, imagePath) {
            const expression = LatexRenderer.processedExpressions[hash];
            handleRenderedLatex(hash);
        }
    }

    spacing: 0
    Repeater {
        id: textLinesRepeater
        model: ScriptModel {
            values: root.fadeChunkSplitting ? root.shownText.split(/\n\n(?= {0,2})|\n(?= {0,2}[-\*])/g).filter(line => line.trim() !== "") : [root.shownText]
        }
        delegate: TextArea {
            id: textArea
            required property int index
            required property string modelData

            readonly property bool liveTail: !root.done && index === textLinesRepeater.count - 1 && !root.editing
            property string committedText: ""
            property int ghostHead: 0
            onModelDataChanged: {
                if (!liveTail) return;
                const g = ghostRepeater.itemAt(ghostHead % 4);
                if (!g) return;
                if (g.text.length > committedText.length) committedText = g.text;
                g.launch(modelData);
                ghostHead++;
            }

            opacity: 1
            Component.onCompleted: {
                committedText = modelData;
                if (root.fadeChunkSplitting && !(root.messageData?.done ?? true))
                    lineAppear.start();
            }
            NumberAnimation {
                id: lineAppear
                target: textArea
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }

            Layout.fillWidth: true
            readOnly: !editing
            selectByMouse: enableMouseSelection || editing
            renderType: Text.NativeRendering
            font.family: Appearance.font.family.reading
            font.hintingPreference: Font.PreferNoHinting
            font.pixelSize: Appearance.font.pixelSize.small
            selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
            selectionColor: Appearance.colors.colSecondaryContainer
            wrapMode: TextEdit.Wrap
            color: root.messageData?.thinking ? Appearance.colors.colSubtext
                : root.messageData?.role === 'user' ? Appearance.m3colors.m3onSecondaryContainer
                : Appearance.colors.colOnLayer1
            textFormat: renderMarkdown ? TextEdit.MarkdownText : TextEdit.PlainText
            property real imageFitWidth: 0
            onWidthChanged: {
                const quantized = Math.floor(width / 20) * 20;
                if (quantized !== imageFitWidth)
                    imageFitWidth = quantized;
            }
            text: {
                const raw = liveTail ? committedText : modelData;
                return (root.editing || !renderMarkdown) ? raw : root.fitLocalImages(raw, imageFitWidth);
            }

            onTextChanged: {
                if (!root.editing) return
                segmentContent = text
            }

            onLinkActivated: (link) => {
                Qt.openUrlExternally(link)
                GlobalStates.sidebarLeftOpen = false
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : 
                    (enableMouseSelection || editing) ? Qt.IBeamCursor : Qt.ArrowCursor
            }

            Repeater {
                id: ghostRepeater
                model: 4
                delegate: TextArea {
                    id: ghost
                    anchors.fill: parent
                    visible: textArea.liveTail && opacity > 0 && text.length > 0
                    opacity: 0
                    enabled: false
                    readOnly: true
                    background: null
                    renderType: Text.NativeRendering
                    font: textArea.font
                    wrapMode: textArea.wrapMode
                    color: textArea.color
                    textFormat: textArea.textFormat
                    text: ""
                    function launch(snapshot) {
                        ghostAnim.stop();
                        text = root.fitLocalImages(snapshot, width);
                        opacity = 0;
                        ghostAnim.start();
                    }
                    NumberAnimation {
                        id: ghostAnim
                        target: ghost
                        property: "opacity"
                        to: 1
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Appearance.font.pixelSize.small * 2.4
                opacity: (!root.done && textArea.index === textLinesRepeater.count - 1
                    && !root.editing) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ColorUtils.transparentize(Appearance.colors.colLayer1, 1) }
                    GradientStop { position: 1.0; color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.08) }
                }
            }

        }
    }
}
