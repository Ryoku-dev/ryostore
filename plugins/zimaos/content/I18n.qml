pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: i18n

    readonly property string lang: {
        var n = Qt.locale().name;
        if (i18n.catalogs[n])
            return n;
        var base = n.split("_")[0];
        return i18n.catalogs[base] ? base : "en";
    }

    readonly property var catalogs: ({
        "pt": {
            "Go to Dashboard": "Ir ao painel",
            "Open": "Abrir",
            "Backup": "Backup",
            "PeerDrop": "PeerDrop",
            "System": "Sistema",
            "CPU": "CPU",
            "RAM": "RAM",
            "Sign in": "Entrar",
            "Sign out": "Sair",
            "Username": "Utilizador",
            "Password": "Palavra-passe",
            "IP": "IP",
            "Enter the ZimaOS address.": "Indique o endereço do ZimaOS.",
            "That address is not valid. Use a hostname or IPv4, with an optional port.": "Endereço inválido. Use um nome ou IPv4, com porta opcional.",
            "Enter the username and the password.": "Indique o utilizador e a palavra-passe.",
            "Could not sign in.": "Não foi possível entrar.",
            "Offline": "Sem resposta",
            "Session expired": "Sessão expirada",
            "Connecting": "A ligar",
            "LAN": "LAN",
            "Remote": "Remoto",
            "Wi-Fi": "Wi-Fi",
            "Ethernet": "Ethernet",
            "Thunderbolt": "Thunderbolt",
            "In use": "Em uso",
            "Available": "Disponível",
            "storage": "armazenamento"
        },
        "pt_BR": {
            "Go to Dashboard": "Ir ao painel",
            "Open": "Abrir",
            "Backup": "Backup",
            "PeerDrop": "PeerDrop",
            "System": "Sistema",
            "CPU": "CPU",
            "RAM": "RAM",
            "Sign in": "Entrar",
            "Sign out": "Sair",
            "Username": "Usuário",
            "Password": "Senha",
            "IP": "IP",
            "Enter the ZimaOS address.": "Informe o endereço do ZimaOS.",
            "That address is not valid. Use a hostname or IPv4, with an optional port.": "Endereço inválido. Use um nome ou IPv4, com porta opcional.",
            "Enter the username and the password.": "Informe o usuário e a senha.",
            "Could not sign in.": "Não foi possível entrar.",
            "Offline": "Sem resposta",
            "Session expired": "Sessão expirada",
            "Connecting": "Conectando",
            "LAN": "LAN",
            "Remote": "Remoto",
            "Wi-Fi": "Wi-Fi",
            "Ethernet": "Ethernet",
            "Thunderbolt": "Thunderbolt",
            "In use": "Em uso",
            "Available": "Disponível",
            "storage": "armazenamento"
        }
    })

    function tr(s) {
        if (s === undefined || s === null || s === "")
            return s;
        var map = i18n.catalogs[i18n.lang];
        if (!map)
            return s;
        var v = map["" + s];
        return v === undefined ? s : v;
    }
}
