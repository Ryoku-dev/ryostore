pragma Singleton
import QtQuick

QtObject {
    id: root

    property var instance: null

    signal emailSent(bool success, string errorMsg)
    signal attachmentDownloadFinished(string attachmentId, bool success, string path)

    property Connections _conn: Connections {
        target: root.instance
        function onEmailSent(success, errorMsg) { root.emailSent(success, errorMsg); }
        function onAttachmentDownloadFinished(attachmentId, success, path) { root.attachmentDownloadFinished(attachmentId, success, path); }
    }

    // State
    readonly property bool authenticated: instance ? instance.authenticated : false
    readonly property bool uiActive: instance ? instance.uiActive : false
    readonly property bool loading: instance ? instance.loading : false
    readonly property bool sendingEmail: instance ? instance.sendingEmail : false
    readonly property bool authenticating: instance ? instance.authenticating : false
    readonly property bool credentialsConfigured: instance ? instance.credentialsConfigured : false
    readonly property bool checkingCredentials: instance ? instance.checkingCredentials : false
    readonly property bool credentialsCheckFailed: instance ? instance.credentialsCheckFailed : false
    readonly property var accounts: instance ? instance.accounts : []
    readonly property int activeAccountIndex: instance ? instance.activeAccountIndex : 0
    readonly property string userEmail: instance ? instance.userEmail : ""
    readonly property string userAvatar: instance ? instance.userAvatar : ""
    readonly property string currentEmailBody: instance ? instance.currentEmailBody : ""
    readonly property string currentEmailHtmlPath: instance ? instance.currentEmailHtmlPath : ""
    readonly property bool loadingEmailBody: instance ? instance.loadingEmailBody : false
    readonly property var currentEmailAttachments: instance ? instance.currentEmailAttachments : null
    readonly property var currentThreadMessages: instance ? instance.currentThreadMessages : null

    // Models
    readonly property var inboxMessages: instance ? instance.inboxMessages : null
    readonly property var starredMessages: instance ? instance.starredMessages : null
    readonly property var sentMessages: instance ? instance.sentMessages : null
    readonly property var trashMessages: instance ? instance.trashMessages : null
    readonly property var spamMessages: instance ? instance.spamMessages : null
    readonly property var importantMessages: instance ? instance.importantMessages : null
    readonly property var purchasesMessages: instance ? instance.purchasesMessages : null
    readonly property var allInboxesMessages: instance ? instance.allInboxesMessages : null
    readonly property var searchMessagesModel: instance ? instance.searchMessagesModel : null
    readonly property var labels: instance ? instance.labels : null

    // Counts
    readonly property int inboxUnreadCount: instance ? instance.inboxUnreadCount : 0
    readonly property int starredUnreadCount: instance ? instance.starredUnreadCount : 0
    readonly property int sentUnreadCount: instance ? instance.sentUnreadCount : 0
    readonly property int trashUnreadCount: instance ? instance.trashUnreadCount : 0
    readonly property int spamUnreadCount: instance ? instance.spamUnreadCount : 0
    readonly property int importantUnreadCount: instance ? instance.importantUnreadCount : 0
    readonly property int purchasesUnreadCount: instance ? instance.purchasesUnreadCount : 0

    // Properties with two-way forwarding to background service
    property int maxEmails: instance ? instance.maxEmails : 20
    onMaxEmailsChanged: { if (instance && instance.maxEmails !== maxEmails) instance.maxEmails = maxEmails; }

    property int refreshIntervalMinutes: instance ? instance.refreshIntervalMinutes : 5
    onRefreshIntervalMinutesChanged: { if (instance && instance.refreshIntervalMinutes !== refreshIntervalMinutes) instance.refreshIntervalMinutes = refreshIntervalMinutes; }

    property bool autoMarkAsRead: instance ? instance.autoMarkAsRead : true
    onAutoMarkAsReadChanged: { if (instance && instance.autoMarkAsRead !== autoMarkAsRead) instance.autoMarkAsRead = autoMarkAsRead; }

    property bool enableAllInboxes: instance ? instance.enableAllInboxes : false
    onEnableAllInboxesChanged: { if (instance && instance.enableAllInboxes !== enableAllInboxes) instance.enableAllInboxes = enableAllInboxes; }

    property bool enableStarred: instance ? instance.enableStarred : true
    onEnableStarredChanged: { if (instance && instance.enableStarred !== enableStarred) instance.enableStarred = enableStarred; }

    property bool enableImportant: instance ? instance.enableImportant : false
    onEnableImportantChanged: { if (instance && instance.enableImportant !== enableImportant) instance.enableImportant = enableImportant; }

    property bool enablePurchases: instance ? instance.enablePurchases : false
    onEnablePurchasesChanged: { if (instance && instance.enablePurchases !== enablePurchases) instance.enablePurchases = enablePurchases; }

    property bool enableSpam: instance ? instance.enableSpam : true
    onEnableSpamChanged: { if (instance && instance.enableSpam !== enableSpam) instance.enableSpam = enableSpam; }

    property bool enableSent: instance ? instance.enableSent : true
    onEnableSentChanged: { if (instance && instance.enableSent !== enableSent) instance.enableSent = enableSent; }

    property bool enableTrash: instance ? instance.enableTrash : true
    onEnableTrashChanged: { if (instance && instance.enableTrash !== enableTrash) instance.enableTrash = enableTrash; }

    property bool enableUpdates: instance ? instance.enableUpdates : true
    onEnableUpdatesChanged: { if (instance && instance.enableUpdates !== enableUpdates) instance.enableUpdates = enableUpdates; }

    property bool enablePromotions: instance ? instance.enablePromotions : true
    onEnablePromotionsChanged: { if (instance && instance.enablePromotions !== enablePromotions) instance.enablePromotions = enablePromotions; }

    property bool enableSocials: instance ? instance.enableSocials : true
    onEnableSocialsChanged: { if (instance && instance.enableSocials !== enableSocials) instance.enableSocials = enableSocials; }

    property bool enableUnreadBadges: instance ? instance.enableUnreadBadges : true
    onEnableUnreadBadgesChanged: { if (instance && instance.enableUnreadBadges !== enableUnreadBadges) instance.enableUnreadBadges = enableUnreadBadges; }

    property bool compactMode: instance ? instance.compactMode : false
    onCompactModeChanged: { if (instance && instance.compactMode !== compactMode) instance.compactMode = compactMode; }

    property bool stackingEnabled: instance ? instance.stackingEnabled : true
    onStackingEnabledChanged: { if (instance && instance.stackingEnabled !== stackingEnabled) instance.stackingEnabled = stackingEnabled; }

    property bool confirmDelete: instance ? instance.confirmDelete : false
    onConfirmDeleteChanged: { if (instance && instance.confirmDelete !== confirmDelete) instance.confirmDelete = confirmDelete; }

    property int bodyFontSize: instance ? instance.bodyFontSize : 14
    onBodyFontSizeChanged: { if (instance && instance.bodyFontSize !== bodyFontSize) instance.bodyFontSize = bodyFontSize; }

    property bool semanticTimestampsEnabled: instance ? instance.semanticTimestampsEnabled : true
    onSemanticTimestampsEnabledChanged: { if (instance && instance.semanticTimestampsEnabled !== semanticTimestampsEnabled) instance.semanticTimestampsEnabled = semanticTimestampsEnabled; }

    property bool showSnippets: instance ? instance.showSnippets : true
    onShowSnippetsChanged: { if (instance && instance.showSnippets !== showSnippets) instance.showSnippets = showSnippets; }

    property bool showAvatars: instance ? instance.showAvatars : true
    onShowAvatarsChanged: { if (instance && instance.showAvatars !== showAvatars) instance.showAvatars = showAvatars; }

    property bool stayInSettingsAfterAccountSwitch: instance ? instance.stayInSettingsAfterAccountSwitch : false
    onStayInSettingsAfterAccountSwitchChanged: { if (instance && instance.stayInSettingsAfterAccountSwitch !== stayInSettingsAfterAccountSwitch) instance.stayInSettingsAfterAccountSwitch = stayInSettingsAfterAccountSwitch; }

    property var enabledLabels: instance ? instance.enabledLabels : []
    onEnabledLabelsChanged: { if (instance && instance.enabledLabels !== enabledLabels) instance.enabledLabels = enabledLabels; }

    property var navOrder: instance ? instance.navOrder : []
    function setNavOrder(newOrder) {
        if (instance) {
            instance.setNavOrder(newOrder);
        }
    }

    // Draft / Temp
    property string composeDraftTo: ""
    property string composeDraftSubject: ""
    property string composeDraftBody: ""
    property var composeDraftAttachments: []
    property string tempGmailClientId: ""
    property string tempGmailClientSecret: ""
    property bool gmailCredentialsTempLoaded: false

    // Methods
    function syncLabel(tab, force) { if (instance) instance.syncLabel(tab, force); }
    function syncInbox(force) { if (instance) instance.syncInbox(force); }
    function syncAll() { if (instance) instance.syncAll(); }
    function syncAllInboxes() { if (instance) instance.syncAllInboxes(); }
    function startOAuth() { if (instance) instance.startOAuth(); }
    function checkCredentials() { if (instance) instance.checkCredentials(); }
    function switchAccount(idx) { if (instance) instance.switchAccount(idx); }
    function removeAccount(idx) { if (instance) instance.removeAccount(idx); }
    function fetchEmailBody(msgId) { if (instance) instance.fetchEmailBody(msgId); }
    function fetchThread(threadId) { if (instance) instance.fetchThread(threadId); }
    function sendEmail(to, subj, body, atts) { if (instance) return instance.sendEmail(to, subj, body, atts); }
    function deleteEmail(msgId, mode) { if (instance) instance.deleteEmail(msgId, mode); }
    function trashMessage(msgId) { if (instance) instance.trashMessage(msgId); }
    function deleteMessagePermanent(msgId) { if (instance) instance.deleteMessagePermanent(msgId); }
    function restoreMessage(msgId) { if (instance) instance.restoreMessage(msgId); }
    function starEmail(msgId, starred) { if (instance) instance.starEmail(msgId, starred); }
    function toggleStarMessage(msgId, currentVal) { if (instance) instance.starEmail(msgId, !currentVal); }
    function markAsRead(msgId) { if (instance) instance.markAsRead(msgId); }
    function markAsUnread(msgId) { if (instance) instance.markAsUnread(msgId); }
    function downloadAttachment(msgId, attId, fname) { if (instance) instance.downloadAttachment(msgId, attId, fname); }
    function searchMessages(query) { if (instance) instance.searchMessages(query); }
    function hasNextPage(tab, page) { return instance ? instance.hasNextPage(tab, page) : false; }
    function getModelForTab(tab) { return instance ? instance.getModelForTab(tab) : null; }
    function formatRelativeDate(ts) { return instance ? instance.formatRelativeDate(ts) : ""; }
    function decrementUnreadForModel(model) { if (instance) instance.decrementUnreadForModel(model); }
}
