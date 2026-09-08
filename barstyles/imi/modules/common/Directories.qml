pragma Singleton

import QtQuick
import Quickshell
import "functions"

Singleton {
    id: root

    property string home: FileUtils.trimFileProtocol(Quickshell.env("HOME") || "/home")
    property string config: FileUtils.trimFileProtocol(Quickshell.env("XDG_CONFIG_HOME") || `${FileUtils.trimFileProtocol(Directories.home)}/.config`)
    property string state: FileUtils.trimFileProtocol(Quickshell.env("XDG_STATE_HOME") || `${FileUtils.trimFileProtocol(Directories.home)}/.local/state`)
    property string cache: FileUtils.trimFileProtocol(Quickshell.env("XDG_CACHE_HOME") || `${FileUtils.trimFileProtocol(Directories.home)}/.cache`)
    property string data: FileUtils.trimFileProtocol(Quickshell.env("XDG_DATA_HOME") || `${FileUtils.trimFileProtocol(Directories.home)}/.local/share`)
    property string scriptPath: Quickshell.shellPath("scripts")
    property string shellConfig: FileUtils.trimFileProtocol(`${Directories.config}/immaterial-impulse`)
    property string shellConfigName: "config.json"
    property string shellConfigPath: `${Directories.shellConfig}/${Directories.shellConfigName}`
    property string notificationsPath: FileUtils.trimFileProtocol(`${Directories.cache}/notifications/notifications.json`)
    property string generatedMaterialThemePath: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/colors.json`)

    property bool configDirReady: true
}
