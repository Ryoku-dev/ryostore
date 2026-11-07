import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Search.mjs" as Search
import "Input.mjs" as Input
import "Navigation.mjs" as Navigation

ShellRoot {
    id: root
    property bool shown: false
    readonly property bool mapped: shown
    property var restoreTarget: null
    Component.onCompleted: Qt.callLater(root.open)
    property bool searching: false
    property bool busy: false
    property var target: null
    property string pending: ""
    property string group: "all"
    property string query: ""
    property string statusKey: "hint.ready"
    property var statusArgs: ({})
    readonly property string status: i18n.saveError || i18n.t(statusKey,statusArgs)
    function setStatus(key,args) {statusKey=key;statusArgs=args||{};}
    function reportInputError(error) {const key=String(error.message||error);setStatus(key.indexOf("input.")===0?key:"error.generic",{detail:key});}
    property var rows: []
    property var groups: Search.groupIds
    property var rawCatalog: null
    property var localeAnnotations: ({})
    property var englishAnnotations: ({})
    property bool englishLoaded: false
    property string catalogLocale: ""
    readonly property bool localizedReady: i18n.language==="en"?englishLoaded:catalogLocale===i18n.language
    property var results: []
    property var hovered: null
    property int selectedIndex: -1
    property bool keyboardNavigation: false
    readonly property var selectedItem: selectedIndex>=0&&selectedIndex<results.length?results[selectedIndex]:null
    readonly property var activeItem: keyboardNavigation?selectedItem:(hovered||selectedItem)
    property string stateDir: Quickshell.env("KEYMOJI_STATE_DIR") || (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/keymoji"
    property string statePath: stateDir+"/history.json"
    readonly property var localization: i18n
    Localization {id:i18n;stateDir:root.stateDir}
    Connections {target:i18n;function onLanguageChanged(){root.localeAnnotations={};root.catalogLocale="";root.reindexCatalog();}}
    function groupName(id) {return i18n.t("group."+id);}
    function groupIcon(id) {
        const icons={all:"layout-grid",recent:"clock",favorites:"star",faces:"mood-smile",people:"hand-stop",nature:"leaf",food:"apple",travel:"plane",activities:"ball-football",objects:"bulb",symbols:"math-symbols",flags:"flag"};
        return icons[id]||"keyboard";
    }
    function reindexCatalog() {
        if(!rawCatalog)return;
        const annotations=i18n.language==="en"?englishAnnotations:localeAnnotations;
        rows=Search.indexCatalog(rawCatalog,annotations,englishAnnotations,i18n.groupLabels,i18n.language);
        apply();
    }
    function apply() {
        results=Search.search(rows,query,group,history.favorites,history.recent);
        selectedIndex=results.length?0:-1;keyboardNavigation=false;hovered=null;
        grid.positionViewAtBeginning();
    }
    function flushQuery() {
        if(debounce.running){debounce.stop();query=searchBox.text;apply();}
    }
    function navigate(direction) {
        flushQuery();
        if(!results.length)return;
        if(keyboardNavigation||direction==='first'||direction==='last'||direction==='pageUp'||direction==='pageDown')
            selectedIndex=Navigation.nextIndex(selectedIndex,direction,results.length,grid.columns,Math.floor(grid.height/grid.cellHeight));
        else selectedIndex=0;
        keyboardNavigation=true;
        grid.positionViewAtIndex(selectedIndex,GridView.Contain);
    }
    function pickSelected() {
        flushQuery();
        if(selectedItem)pick(selectedItem.e);
    }
    function remember(e) { history.recent = [e].concat(history.recent.filter(x=>x!==e)).slice(0,48); store.writeAdapter(); apply(); }
    function favorite(e) { history.favorites = history.favorites.indexOf(e)>=0 ? history.favorites.filter(x=>x!==e) : history.favorites.concat([e]); store.writeAdapter(); apply(); }
    function open() {
        if(busy)return;
        target=ToplevelManager.activeToplevel;
        restoreFocus.stop();restoreTarget=null;shown=true;searching=true;Motion.refresh();
        keyboardNavigation=false;
        setStatus("hint.navigation");
        Qt.callLater(function(){if(root.shown)searchBox.forceActiveFocus();});
    }
    function releaseFocus() {
        searching=false;
        searchBox.focus=false;
        restoreTarget=target;
        restoreFocus.restart();
    }
    Timer {
        id: restoreFocus; interval: 35
        onTriggered: {
            const active=ToplevelManager.activeToplevel;
            if(!root.searching&&root.restoreTarget&&(!active||active===root.restoreTarget))root.restoreTarget.activate();
            root.restoreTarget=null;
        }
    }
    function hide() {
        if(!shown)return;
        release.stop();shown=false;releaseFocus();target=null;
        if(!inject.running){busy=false;pending="";}
    }
    function pick(e) {
        if(busy) return;
        if(!searching) target=ToplevelManager.activeToplevel;
        busy=true; pending=e; releaseFocus(); release.start();
    }
    function beginSearch() {
        if(busy||searching)return;
        target=ToplevelManager.activeToplevel;
        if(!target) {setStatus("input.noTarget");return;}
        searching=true;
        searchBox.forceActiveFocus();
    }
    IpcHandler { target: "keymoji"; function toggle(): void { if(root.shown)root.hide();else root.open(); } function hide(): void {root.hide();} function setLanguage(code: string): void {i18n.setLanguage(code);} function state(): string {return JSON.stringify({language:i18n.language,languagePreference:i18n.requestedLanguage,languageSource:i18n.source,localizedReady:root.localizedReady,sampleName:root.rows.length?root.rows[0].n:null,tagline:i18n.t("tagline"),visible:root.shown,mapped:root.mapped,windowVisible:panel.visible,backingVisible:panel.backingWindowVisible,inputRegion:{width:panel.mask.width,height:panel.mask.height},pointerInput:root.shown,searchFocused:searchBox.activeFocus,selectedIndex:root.selectedIndex,selectedEmoji:root.selectedItem?root.selectedItem.e:null,keyboardNavigation:root.keyboardNavigation,columns:grid.columns,scrollY:grid.contentY,resultCount:root.results.length,searching:root.searching,motionOwner:"compositor",motion:Motion.settings,adaptiveTheme:Theme.adaptive,colors:Theme.roles});} }
    FileView {
        path: Quickshell.shellPath("../data/emojis.json")
        onLoaded: {
            try {root.rawCatalog=JSON.parse(text());root.reindexCatalog();}
            catch(e){root.setStatus("error.catalogParse",{detail:String(e)});}
        }
        onLoadFailed: root.setStatus("error.catalogRead")
    }
    FileView {
        path:Quickshell.shellPath("../data/i18n/en.json");printErrors:false
        onLoaded:{try{root.englishAnnotations=JSON.parse(text());root.englishLoaded=true;root.reindexCatalog();}catch(e){root.setStatus("language.localeError");}}
        onLoadFailed:root.setStatus("language.localeError")
    }
    FileView {
        path:i18n.language==="en"?"":Quickshell.shellPath("../data/i18n/"+i18n.language+".json");printErrors:false
        onLoaded:{try{root.localeAnnotations=JSON.parse(text());root.catalogLocale=i18n.language;root.reindexCatalog();}catch(e){root.setStatus("language.localeError");}}
        onLoadFailed:if(i18n.language!=="en")root.setStatus("language.localeError")
    }
    FileView {
        id: store; path: root.statePath; onLoaded: root.apply()
        onSaveFailed: root.setStatus("error.historySave")
        JsonAdapter { id: history; property var recent: []; property var favorites: [] }
    }
    Timer {
        id: release; interval: 100
        onTriggered: {
            try { inject.error=""; inject.command=Input.command(root.pending,root.target,ToplevelManager.activeToplevel,root.searching); inject.running=true; }
            catch(e){root.reportInputError(e);root.busy=false;root.pending="";}
        }
    }
    Process {
        id: inject
        property string error: ""
        stderr: StdioCollector { onStreamFinished: inject.error=text.trim() }
        onExited: (code) => {
            root.busy=false;
            if(code===0){root.remember(root.pending);root.setStatus("sent",{emoji:root.pending});}
            else root.setStatus(inject.error?"error.backend":"error.insert",{detail:inject.error});
            root.pending="";
        }
    }
    PanelWindow {
        id: panel
        visible: root.mapped
        anchors { top: true; bottom: true; left: true; right: true }
        implicitWidth: screen.width
        implicitHeight: screen.height
        exclusiveZone: 0
        color: "transparent"
        // Empty input region immediately on close, even while the fade is visible.
        mask: Region { width: root.shown ? panel.width : 0; height: root.shown ? panel.height : 0 }
        WlrLayershell.namespace: "keymoji"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.searching ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.hide() }
        Rectangle {
            id: surface
            anchors { bottom: parent.bottom; right: parent.right; margins: 24 }
            width: Math.min(528, panel.width-48)
            height: Math.min(590, panel.height-48)
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: event => event.accepted=true }
            radius: 20; color: Theme.surface; border.color: Theme.border
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 20; spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth:true;Layout.minimumWidth:0
                        spacing: 3
                        Text { text: "keymoji"; color: Theme.accent; font.pixelSize: 25; font.weight: Font.DemiBold }
                        Text { Layout.fillWidth:true;elide:Text.ElideRight;text:i18n.t("tagline"); color: Theme.muted; font.pixelSize: 9; font.letterSpacing: 2 }
                    }
                    LanguagePicker {i18n:root.localization;onChosen:Qt.callLater(function(){if(root.searching)searchBox.forceActiveFocus();})}
                    Key { icon: "x"; accessibleLabel:i18n.t("close"); onClicked: root.hide() }
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 44; radius: 11; color: Theme.raised; border.color: root.searching?Theme.accent:Theme.border
                    Icon {name:"search";width:18;height:18;anchors.left:parent.left;anchors.leftMargin:12;anchors.verticalCenter:parent.verticalCenter;ink:Theme.muted}
                    TextField {
                        id: searchBox; anchors.fill:parent; anchors.margins:4; anchors.leftMargin:34
                        placeholderText: i18n.t(root.searching?"search.placeholder":"search.idle")
                        color:Theme.ink; placeholderTextColor:Theme.muted; font.pixelSize:14
                        background: Item {} readOnly: !root.searching
                        onTextChanged: {root.keyboardNavigation=false;root.hovered=null;debounce.restart();}
                        onAccepted: root.pickSelected()
                        Keys.priority: Keys.BeforeItem
                        Keys.onPressed: event => {
                            if(event.modifiers!==Qt.NoModifier)return;
                            const directions={};
                            directions[Qt.Key_Left]="left";directions[Qt.Key_Right]="right";
                            directions[Qt.Key_Up]="up";directions[Qt.Key_Down]="down";
                            directions[Qt.Key_PageUp]="pageUp";directions[Qt.Key_PageDown]="pageDown";
                            if(root.keyboardNavigation){directions[Qt.Key_Home]="first";directions[Qt.Key_End]="last";}
                            const direction=directions[event.key];
                            if(!direction)return;
                            // Keep left/right available to edit a non-empty query until entering the grid.
                            if(!root.keyboardNavigation&&searchBox.text.length&&(direction==="left"||direction==="right"))return;
                            root.navigate(direction);event.accepted=true;
                        }
                        Keys.onEscapePressed: root.hide()
                        MouseArea {anchors.fill:parent;enabled:!root.searching;onClicked:root.beginSearch()}
                    }
                }
                Timer {id:debounce;interval:65;onTriggered:{root.query=searchBox.text;root.apply();}}
                Text { Layout.fillWidth:true; text:i18n.t(root.searching?"hint.navigation":"hint.typing"); color:Theme.muted; font.pixelSize:11;wrapMode:Text.WordWrap }
                Flickable {
                    Layout.fillWidth:true; implicitHeight:36; contentWidth:categories.width; contentHeight:36; clip:true; flickableDirection:Flickable.HorizontalFlick
                    Row {id:categories;spacing:6;Repeater {model:root.groups;Key {required property string modelData;label:root.groupName(modelData);icon:root.groupIcon(modelData);selected:root.group===modelData;onClicked:{root.group=modelData;root.apply();}}}}
                }
                RowLayout {Layout.fillWidth:true
                    Text {text:root.groupName(root.group); color:Theme.ink;font.pixelSize:13;font.bold:true}
                    Item {Layout.fillWidth:true}
                    Text {text:i18n.count(root.results.length);color:Theme.muted;font.pixelSize:11}
                }
                GridView {
                    id:grid; Layout.fillWidth:true;Layout.fillHeight:true;clip:true
                    readonly property int columns: Math.max(1,Math.floor(width/54))
                    cellWidth:width/columns;cellHeight:52
                    currentIndex:root.selectedIndex
                    onWidthChanged: if(root.keyboardNavigation&&root.selectedIndex>=0)Qt.callLater(function(){grid.positionViewAtIndex(root.selectedIndex,GridView.Contain);})
                    model:root.results;boundsBehavior:Flickable.StopAtBounds
                    add: Transition { NumberAnimation { property:"opacity";from:0;to:1;duration:Motion.transitionMs;easing.type:Easing.BezierSpline;easing.bezierCurve:Motion.transitionCurve } }
                    ScrollBar.vertical: ScrollBar {policy:ScrollBar.AsNeeded}
                    delegate: Rectangle {
                        id:cell;required property var modelData;required property int index
                        readonly property bool keyboardSelected:root.keyboardNavigation&&root.selectedIndex===index
                        width:grid.cellWidth-4;height:48;radius:10
                        color:(keyboardSelected||hit.containsMouse)?Theme.hover:"transparent"
                        border.color:(keyboardSelected||hit.containsMouse)?Theme.accent:"transparent"
                        border.width:keyboardSelected?2:1
                        Accessible.role:Accessible.Button;Accessible.name:modelData.n
                        Accessible.onPressAction:root.pick(modelData.e)
                        Text {anchors.centerIn:parent;text:cell.modelData.e;font.family:"Noto Color Emoji";font.pixelSize:28}
                        Icon {anchors.right:parent.right;anchors.top:parent.top;width:10;height:10;name:"star";visible:history.favorites.indexOf(cell.modelData.e)>=0;ink:Theme.accent}
                        MouseArea {id:hit;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor
                            onEntered:root.hovered=cell.modelData
                            onClicked:(mouse)=>{if(mouse.button===Qt.RightButton)root.favorite(cell.modelData.e);else root.pick(cell.modelData.e);}
                        }
                        ToolTip.visible:hit.containsMouse;ToolTip.delay:650;ToolTip.text:modelData.n+"\n"+modelData.code+"\n"+i18n.t("favorite.hint")
                    }
                    Text {anchors.centerIn:parent;visible:root.results.length===0;text:i18n.t(root.rows.length?"empty":"loading");horizontalAlignment:Text.AlignHCenter;color:Theme.muted}
                }
                Rectangle {Layout.fillWidth:true;implicitHeight:1;color:Theme.border}
                RowLayout {Layout.fillWidth:true
                    Text {Layout.fillWidth:true;text:root.activeItem?root.activeItem.e+"  "+root.activeItem.n:i18n.t("footer");color:Theme.ink;font.pixelSize:12;elide:Text.ElideRight}
                    Key {icon:"star";selected:!!root.activeItem&&history.favorites.indexOf(root.activeItem.e)>=0;accessibleLabel:i18n.t("favorite.toggle");onClicked:if(root.activeItem)root.favorite(root.activeItem.e)}
                }
                Text {Layout.fillWidth:true;text:root.busy?i18n.t("inserting"):root.status;color:Theme.muted;font.pixelSize:11;wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight}
            }
        }
    }
}
