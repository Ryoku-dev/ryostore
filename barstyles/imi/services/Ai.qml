pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Ai is not in this port; members read as empty.
Singleton {
    property var approvalCardKinds: null
    property var attachments: null
    property var availableTools: null
    property var basePrompt: null
    property var catalog: ({})
    property var contextCutMessageId: null
    property var contextReserve: null
    property var contextSummary: null
    property string currentModelAlwaysThinks: ""
    property var currentModelEntry: ({})
    property bool currentModelHasApiKey: false
    property var currentModelSupportsVision: null
    property real currentModelTakesFiles: 0
    property bool currentModelThinks: false
    property var currentPersona: ({})
    property var currentProject: ({})
    property var currentPromptFile: null
    property list<var> currentProvider: []
    property string currentTool: ""
    property var draft: ({})
    property var enabled: null
    property real estimatedContextTokens: 0
    property list<var> interfaceRole: []
    property var isGenerating: null
    property var lastAnswerTokensPerSecond: null
    property real maxTemperature: 0
    property list<var> messageByID: []
    property real messageIDs: 0
    property var models: null
    property list<var> modelsOfProviders: []
    property var modesIntegration: null
    property var ownPromptHistory: null
    property bool personaModified: false
    property var personas: ({})
    property var pickingFiles: null
    property var projects: null
    property list<var> promptFiles: []
    property list<var> promptOverride: []
    property var providerIds: null
    property list<var> providers: []
    property var prunedTurnCount: null
    property string qml: ""
    property var retryMessageId: null
    property list<var> retryNotice: []
    property var runCoordinator: null
    property var sessionOpenRouterCost: null
    property list<var> sessionParentId: []
    property var sessionPersonaId: null
    property var sessionProjectId: ({})
    property string sessionTitle: ""
    property var sessionTokenTotal: null
    property var sessions: ({})
    property var settingsIntegration: null
    property var surfaceRouter: null
    property string temperature: ""
    property real thinkingLevel: 0
    property var thinkingLevels: null
    property real tokenCount: 0
    property list<var> toolDescriptions: []
    property var toolbox: null
    property var userPrompts: null
    property string voiceService: ""
    function addMessage() {
    }
    function answerVariantSessionIds() {
    }
    function attachActiveWindowContext() {
    }
    function attachClipboardContext() {
    }
    function attachFile() {
    }
    function attachLauncherContext() {
    }
    function clearAttachments() {
    }
    function clearDraftIfCurrent() {
    }
    function commitMemory() {
    }
    function composerReferenceSources() {
    }
    function continueMessage() {
    }
    function editAndResend() {
    }
    function estimateMessageTokens() {
    }
    function estimateTokens() {
    }
    function expandComposerReferences() {
    }
    function forkFrom() {
    }
    function formatOpenRouterCost() {
    }
    function formatTokensPerSecond() {
    }
    function humanSize() {
    }
    function isFreshMessage() {
    }
    function isTranscriptEntry() {
    }
    function keyManagerRequested() {
    }
    function leadingActivityMessages() {
    }
    function loadPrompt() {
    }
    function nameCurrentChat() {
    }
    function newChat() {
    }
    function openAnswerVariant() {
    }
    function openChatByName() {
    }
    function openSession() {
    }
    function pickFiles() {
    }
    function printApiKey() {
    }
    function printPrompt() {
    }
    function printTemperature() {
    }
    function regenerate() {
    }
    function regenerateWith() {
    }
    function rejectMemory() {
    }
    function removeMessage() {
    }
    function retryMessage() {
    }
    function sendUserMessage() {
    }
    function setApiKey() {
    }
    function setFunctionExposure() {
    }
    function setModel() {
    }
    function setPersona() {
    }
    function setProject() {
    }
    function setPromptOverride() {
    }
    function setProvider() {
    }
    function setResponseMode() {
    }
    function setTemperature() {
    }
    function setThinkingLevel() {
    }
    function setTool() {
    }
    function setWebMode() {
    }
    function shortTokenCount() {
    }
    function shouldShowAnswerVariants() {
    }
    function stopGeneration() {
    }
    function submit() {
    }
    function substituted() {
    }
    function transportErrorAdvice() {
    }
    function visibleToolCards() {
    }
    function wasTruncated() {
    }
}
