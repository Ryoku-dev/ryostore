.pragma library

// What the radial menu offers for a set of dragged files: DragShift's
// app.build_rings, ported so the rings appear the instant a drag enters (no
// Python start-up in the way). tests/test_menu.py checks every entry against
// the engine, so the two can never drift apart.

const IMAGE_EXTS = ["png", "jpg", "jpeg", "webp", "heic", "heif", "tif", "tiff", "avif", "bmp", "gif", "ico"];
const TEXT_EXTS = ["txt", "md", "csv", "log", "json", "xml", "html", "htm"];
// bin/ds_archive.py and bin/ds_media.py
const ARCHIVE_SUFFIXES = [".tar.gz", ".tar.xz", ".tar.bz2", ".tgz", ".txz", ".tbz2", ".zip", ".tar"];
const VIDEO_EXTS = ["mp4", "mov", "mkv", "webm", "avi", "m4v"];
const AUDIO_EXTS = ["mp3", "m4a", "wav", "flac", "ogg", "opus"];

const IMAGE_TARGETS = ["PNG", "JPG", "WEBP", "HEIC", "TIFF", "AVIF", "BMP", "PDF", "ICO", "GIF"];
const PDF_TARGETS = ["JPG", "PNG", "DOCX", "TXT"];
const DOCX_TARGETS = ["PDF", "TXT"];
const TEXT_TARGETS = ["PDF", "DOCX"];
const VIDEO_TARGETS = ["MP4", "WEBM", "GIF", "MP3"];
const AUDIO_TARGETS = ["MP3", "OPUS", "WAV", "FLAC"];

const FORMAT_HINTS = {
    JPG: "Small, universal", PNG: "Lossless · transparency", WEBP: "Smallest for web",
    HEIC: "iPhone format", TIFF: "Print · archival", AVIF: "Next-gen, tiny",
    BMP: "Uncompressed", PDF: "Document", ICO: "Windows icon", GIF: "Legacy web",
    DOCX: "Editable Word", TXT: "Plain text"
};
const MEDIA_HINTS = {
    MP4: "Plays everywhere", WEBM: "Open web video", GIF: "First 15 s · 480 px", MP3: "Universal audio",
    OPUS: "Small, great quality", WAV: "Uncompressed", FLAC: "Lossless"
};

const GLYPHS = {
    Compress: "⇲", Metadata: "ⓘ", Redact: "▮", Crop: "⌗", Edit: "☼", Annotate: "✎",
    "Add BG": "▣", Resize: "⤢", Split: "✂", Rotate: "⟳", Merge: "⧉", Protect: "⚿", Extract: "⧈",
    Copy: "❐", Text: "¶", Translate: "⇄", "Copy path": "⎘", Numbers: "#", Gray: "◐", Flatten: "▭", Halves: "½",
    Chapters: "§", Searchable: "⌕", Organize: "▦", Watermark: "≋", Unlock: "⚷", Unpack: "⤓", "→ WEBP": "▦", "→ JPG": "▦", "Shrink all": "⇲"
};

const HINTS = {
    Compress: "Shrink file size", Metadata: "View · remove GPS", Redact: "Hide private info",
    Crop: "Trim to a ratio", Edit: "Light · colour · rotate", Annotate: "Arrows · text · steps",
    "Add BG": "Gradient backdrop", Resize: "Change dimensions", Split: "One PDF per page",
    Rotate: "Turn pages 90°", Merge: "Join into one PDF", Protect: "Add a password",
    Extract: "Save embedded images", Copy: "Paste it anywhere", Translate: "Opens in Oumu", Text: "Read text · copy it",
    "Copy path": "Full path to clipboard", Numbers: "Add page numbers", Gray: "Black & white copy",
    Flatten: "Bake in forms · notes", Halves: "Split into two", Chapters: "One PDF per bookmark",
    Searchable: "OCR scanned pages", Organize: "Reorder · delete · cut · merge", Watermark: "Text or image stamp",
    Unlock: "Remove the password", Unpack: "Into a new folder", "→ WEBP": "Every image inside",
    "→ JPG": "Every image inside", "Shrink all": "Compress every image"
};

// label -> [kind, engine id]. "editor" opens DragShift's own window, "tool" runs at once.
const IMAGE_TOOLS = [
    ["Compress", "editor", "compress-custom"], ["Resize", "editor", "resize-custom"],
    ["Crop", "editor", "crop"], ["Edit", "editor", "edit"], ["Annotate", "editor", "annotate"],
    ["Redact", "editor", "redact"], ["Add BG", "editor", "add-bg"], ["Metadata", "editor", "metadata"],
    ["Copy", "tool", "copy"], ["Text", "tool", "ocr"]
];
const PDF_TOOLS = [
    ["Compress", "tool", "compress"], ["Split", "tool", "split"], ["Rotate", "tool", "rotate"],
    ["Extract", "tool", "extract"], ["Numbers", "tool", "numbers"], ["Gray", "tool", "gray"],
    ["Flatten", "tool", "flatten"]
];
const PDF_PAGES = [
    ["Organize", "editor", "organize"], ["Watermark", "editor", "watermark"], ["Protect", "editor", "protect"],
    ["Unlock", "editor", "unlock"], ["Metadata", "editor", "metadata"], ["Halves", "tool", "halves"],
    ["Chapters", "tool", "chapters"], ["Searchable", "tool", "searchable"]
];

const ARCHIVE_ITEMS = [["ZIP", "zip", "Opens anywhere"], ["TAR.GZ", "tar-gz", "Linux standard"],
                       ["TAR.XZ", "tar-xz", "Smallest"]];
const FOLDER_TOOLS = [["→ WEBP", "tool", "batch-webp"], ["→ JPG", "tool", "batch-jpg"],
                      ["Shrink all", "tool", "batch-compress"]];

function name(p) {
    const s = String(p);
    return s.slice(s.lastIndexOf("/") + 1);
}

function archiveSuffix(p) {
    const n = name(p).toLowerCase();
    return ARCHIVE_SUFFIXES.find(s => n.endsWith(s) && n.length > s.length) || "";
}

function ext(p) {
    const s = String(p);
    const name = s.slice(s.lastIndexOf("/") + 1);
    const dot = name.lastIndexOf(".");
    return dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
}

// `kinds` ({path: "dir" | "file"}, optional) is what stat said; without it an
// extensionless item is taken for a folder, which only adds the batch ring.
function category(p, kinds) {
    const k = kinds ? kinds[String(p)] : undefined;
    if (k === "dir") return "folder";
    if (archiveSuffix(p)) return "archive";
    const e = ext(p);
    if (e === "" && k !== "file" && name(p) !== "" && name(p)[0] !== ".") return "folder";
    if (VIDEO_EXTS.indexOf(e) !== -1) return "video";
    if (AUDIO_EXTS.indexOf(e) !== -1) return "audio";
    if (IMAGE_EXTS.indexOf(e) !== -1) return "image";
    if (e === "pdf") return "pdf";
    if (e === "docx") return "docx";
    if (TEXT_EXTS.indexOf(e) !== -1) return "text";
    return "";
}

// convert.targets_for: every target except the format the file already is
function targetsFor(cat, srcExt, heif) {
    const same = { jpeg: "JPG", jpg: "JPG", tif: "TIFF", tiff: "TIFF", heif: "HEIC", m4v: "MP4", ogg: "OPUS" };
    const cur = same[srcExt] || String(srcExt).toUpperCase();
    if (cat === "image")
        return IMAGE_TARGETS.filter(t => t !== cur && (heif || t !== "HEIC"));
    if (cat === "video" || cat === "audio")
        return (cat === "video" ? VIDEO_TARGETS : AUDIO_TARGETS).filter(t => t !== cur);
    return ({ pdf: PDF_TARGETS, docx: DOCX_TARGETS, text: TEXT_TARGETS })[cat] || [];
}

function tool(t) {
    return { label: t[0], glyph: GLYPHS[t[0]], hint: HINTS[t[0]], kind: t[1], id: t[2] };
}

// Archive and Copy path take every dragged path (`all`), whatever its kind.
function archiveRing() {
    return { name: "Archive", items: ARCHIVE_ITEMS.map(a => ({ label: a[0], glyph: "", hint: a[2], kind: "tool", id: a[1], all: true }))
                                     .concat([Object.assign(tool(["Copy path", "tool", "copy-path"]), { all: true })]) };
}

// -> { category, files, rings: [{ name, items: [{label, glyph, hint, kind, id, all?}] }] }
// The first file of a known kind decides; the rest of that kind come along.
// Only folders: "folder". Nothing known: "any", which can still be archived.
function build(paths, heif, kinds) {
    const all = (paths || []).map(String);
    if (all.length === 0)
        return { category: "", files: [], rings: [] };
    const cats = all.map(p => category(p, kinds));
    const cat = cats.find(c => c !== "" && c !== "folder");
    if (!cat) {
        const onlyFolders = cats.every(c => c === "folder");
        const rings = [archiveRing()];
        if (onlyFolders)
            rings.push({ name: "Images", items: FOLDER_TOOLS.map(tool) });
        return { category: onlyFolders ? "folder" : "any", files: all, rings: rings };
    }
    const files = all.filter((p, i) => cats[i] === cat);
    if (cat === "archive")
        return { category: cat, files: files, rings: [{ name: "Tools", items: [
            tool(["Unpack", "tool", "extract"]),
            Object.assign(tool(["Copy path", "tool", "copy-path"]), { all: true })] }] };
    const media = cat === "video" || cat === "audio";
    const conv = targetsFor(cat, ext(files[0]), heif !== false).map(t => ({
        label: t, glyph: "", kind: "convert", id: t,
        hint: (cat === "image" && t === "PDF" && files.length > 1) ? files.length + " images → 1 PDF"
            : (media ? MEDIA_HINTS[t] : FORMAT_HINTS[t]) || ""
    }));
    if (cat === "video")
        conv.push(tool(["Compress", "tool", "compress"]));
    const rings = [{ name: "Convert", items: conv }];
    let tools = cat === "image" ? IMAGE_TOOLS.slice() : cat === "pdf" ? PDF_TOOLS.slice() : [];
    if (cat === "pdf" && files.length > 1)
        tools.splice(3, 0, ["Merge", "tool", "merge"]);
    if (tools.length > 0)
        rings.push({ name: "Tools", items: tools.map(tool) });
    if (cat === "pdf")
        rings.push({ name: "Pages", items: PDF_PAGES.map(tool) });
    rings.push(archiveRing());
    return { category: cat, files: files, rings: rings };
}

// Dragged text (a highlight from any app). "oumu" items go to the Oumu app over
// its socket (without Oumu, picking one says how to get it); "text" items run here.
const TEXT_ITEMS = [["Translate", "oumu", "translate"], ["Copy", "text", "copy"]];

function buildText(text) {
    if (String(text || "").trim() === "")
        return { category: "", files: [], rings: [] };
    const items = TEXT_ITEMS.map(tool);
    return { category: "text-selection", files: [], rings: [{ name: "Text", items: items }] };
}

function wordCount(text) {
    return String(text || "").split(/\s+/).filter(w => w.length > 0).length;
}

// app.describe: "2.4 MB" for one file, "3 files" for several
function humanSize(n) {
    const units = ["B", "KB", "MB", "GB"];
    let v = Number(n) || 0;
    let i = 0;
    while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
    return (i === 0 ? v.toFixed(0) : v.toFixed(1)) + " " + units[i];
}
