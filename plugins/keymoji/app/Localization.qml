import QtQuick
import Quickshell
import Quickshell.Io
import "i18n/Locale.mjs" as Locale
import "i18n/Messages.mjs" as Messages
Scope {
    id: root
    property string stateDir: ""
    property string desktopLanguage: ""
    property string saveError: ""
    readonly property var resolution: Locale.resolve(settings.language,desktopLanguage,{LC_ALL:Quickshell.env("LC_ALL"),LANGUAGE:Quickshell.env("LANGUAGE"),LC_MESSAGES:Quickshell.env("LC_MESSAGES"),LANG:Quickshell.env("LANG"),qtLocale:Qt.locale().name})
    readonly property string language: resolution.language
    readonly property string requestedLanguage: resolution.requested
    readonly property string source: resolution.source
    readonly property var options: Locale.languages
    readonly property var groupLabels: {
        const out={};const data=Messages.messages[language]||Messages.messages.en;
        Object.keys(data).filter(key=>key.indexOf("group.")===0).forEach(key=>out[key.slice(6)]=data[key]);return out;
    }
    function t(key,args) {return Locale.format((Messages.messages[language]||{})[key]||Messages.messages.en[key]||key,args);}
    function count(value) {return t(Locale.countKey(language,value),{count:value});}
    function nativeName(code) {return Locale.nativeNames[code]||code;}
    function setLanguage(code) {
        if(Locale.languages.indexOf(code)<0)return;
        settings.language=code;saveError="";preferences.writeAdapter();
    }
    FileView {
        id: preferences
        path: root.stateDir ? root.stateDir+"/settings.json" : ""
        blockLoading: true;watchChanges: true;printErrors:false
        onFileChanged: reload()
        onSaveFailed: root.saveError=root.t("language.saveError")
        JsonAdapter { id:settings;property string language:"auto" }
    }
    FileView {
        path:(Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME")+"/.config")+"/ryoku/shell.json"
        blockLoading:true;watchChanges:true;printErrors:false
        onFileChanged:reload()
        onLoaded:{try{root.desktopLanguage=JSON.parse(text()).language||"";}catch(e){}}
    }
}
