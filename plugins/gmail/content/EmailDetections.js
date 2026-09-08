// EmailDetections.js

function detectAll(bodyRaw) {
    if (!bodyRaw) {
        return {
            meetings: [],
            phones: [],
            codes: []
        };
    }

    var clean = bodyRaw.replace(/<style[\s\S]*?<\/style>/gi, '')
                       .replace(/<script[\s\S]*?<\/script>/gi, '')
                       .replace(/<br\s*\/?>/gi, '\n')
                       .replace(/<\/p>/gi, '\n')
                       .replace(/<\/div>/gi, '\n')
                       .replace(/<[^>]*>?/gm, ' ');
    var textNoUrls = clean.replace(/https?:\/\/[^\s]+/gi, ' ');

    var meetings = [];
    var m;

    // Meet
    var meetRegex = /https?:\/\/meet\.google\.com\/[a-z0-9-]+/gi;
    while ((m = meetRegex.exec(bodyRaw)) !== null) {
        meetings.push({
            type: "Meet",
            url: m[0],
            icon: "video_chat"
        });
    }

    // Teams
    var teamsRegex1 = /https?:\/\/teams\.microsoft\.com\/l\/meetup-join\/[^\s"<>'{}|\\^`[\]]+/gi;
    while ((m = teamsRegex1.exec(bodyRaw)) !== null) {
        meetings.push({
            type: "Teams",
            url: m[0],
            icon: "groups"
        });
    }

    var teamsRegex2 = /https?:\/\/teams\.microsoft\.com\/v2\/\?meetingjoin=true#\/meet\/[^\s"<>'{}|\\^`[\]]+/gi;
    while ((m = teamsRegex2.exec(bodyRaw)) !== null) {
        meetings.push({
            type: "Teams",
            url: m[0],
            icon: "groups"
        });
    }

    // Zoom
    var zoomRegex = /https?:\/\/zoom\.us\/j\/[0-9]+(?:\?pwd=[a-zA-Z0-9]+)?/gi;
    while ((m = zoomRegex.exec(bodyRaw)) !== null) {
        meetings.push({
            type: "Zoom",
            url: m[0],
            icon: "video_call"
        });
    }

    // Filter duplicate meetings
    var uniqueMeetings = meetings.filter(function(v, i, a) {
        return a.findIndex(function(t) { return t.url === v.url; }) === i;
    });

    // Phones
    var phones = [];
    var phoneRegex = /(?:\+?55\s*)?(?:\(\d{2}\)\s*|\d{2}\s+)?(?:9\s*)?\d{4}[-.\s]?\d{4}/g;
    var phoneKeywords = /(?:tel|phone|celular|whatsapp|contato|ligar|fone|mobile|contatos|telefones)/i;
    while ((m = phoneRegex.exec(clean)) !== null) {
        var p = m[0].trim();
        if (p.length >= 8) {
            var hasPlus55 = p.indexOf("+55") !== -1 || p.indexOf("55") === 0;
            var hasDDDInParens = /\(\d{2}\)/.test(p);
            if (hasPlus55 || hasDDDInParens) {
                if (phones.indexOf(p) === -1) {
                    phones.push(p);
                }
            } else {
                var start = Math.max(0, m.index - 30);
                var end = Math.min(clean.length, m.index + p.length + 30);
                var context = clean.slice(start, end);
                if (phoneKeywords.test(context)) {
                    if (phones.indexOf(p) === -1) {
                        phones.push(p);
                    }
                }
            }
        }
    }

    // Codes (OTP)
    var codes = [];
    var keywords = "(código|code|token|senha|password|verificação|verification|acesso|access|pin)";
    var codeRegex = new RegExp(keywords + "[:\\s]+([A-Z0-9]{4,10})(?![A-Z0-9])", "gi");
    while ((m = codeRegex.exec(textNoUrls)) !== null) {
        if (m[2] && !/^[0-9]{1,3}$/.test(m[2])) {
            if (codes.indexOf(m[2]) === -1) {
                codes.push(m[2]);
            }
        }
    }

    return {
        meetings: uniqueMeetings,
        phones: phones,
        codes: codes
    };
}
