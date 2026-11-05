#!/usr/bin/env python3
"""Read MedKit medicines and cache bounded OpenFDA label details."""

import argparse
import datetime
import html
import json
import os
import re
import tempfile
import urllib.error
import urllib.parse
import urllib.request

OPENFDA_HOST = "api.fda.gov"
MAX_FILE_BYTES = 4 * 1024 * 1024
MAX_RESPONSE_BYTES = 2 * 1024 * 1024
MAX_MEDICINES = 256
MAX_TEXT_BYTES = 20_000


def xdg_path(env_name, fallback):
    value = os.environ.get(env_name, "")
    return value if os.path.isabs(value) else os.path.expanduser(fallback)


MEDKIT_PATH = os.path.join(
    xdg_path("XDG_DATA_HOME", "~/.local/share"), "medkit", "medicines.json"
)
CACHE_PATH = os.path.join(
    xdg_path("XDG_STATE_HOME", "~/.local/state"),
    "ryoku",
    "plugins",
    "medkit-guide",
    "medicine-cache.json",
)


def load_json(path):
    try:
        with open(path, "rb") as source:
            payload = source.read(MAX_FILE_BYTES + 1)
        if len(payload) > MAX_FILE_BYTES:
            return None
        return json.loads(payload.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None


def save_json(path, data):
    parent = os.path.dirname(path)
    os.makedirs(parent, mode=0o700, exist_ok=True)
    os.chmod(parent, 0o700)
    descriptor, temporary = tempfile.mkstemp(
        dir=parent, prefix=".medicine-cache.", text=True
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as target:
            json.dump(data, target, ensure_ascii=False, separators=(",", ":"))
            target.flush()
            os.fsync(target.fileno())
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def openfda_url_allowed(url):
    parsed = urllib.parse.urlsplit(url)
    return parsed.scheme == "https" and parsed.hostname == OPENFDA_HOST


class OpenFDARedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file_pointer, code, message, headers, new_url):
        if not openfda_url_allowed(new_url):
            raise urllib.error.HTTPError(
                new_url, code, "OpenFDA redirected to an untrusted host", headers, None
            )
        return super().redirect_request(
            request, file_pointer, code, message, headers, new_url
        )


OPENFDA = urllib.request.build_opener(OpenFDARedirectHandler())


def clean_text(value, limit=MAX_TEXT_BYTES):
    if isinstance(value, list):
        value = value[0] if value else ""
    if not isinstance(value, str):
        return ""
    value = value[: limit * 2]
    value = re.sub(r"<br\s*/?>", "\n", value, flags=re.IGNORECASE)
    value = re.sub(r"<[^>]+>", "", value)
    return html.unescape(value).strip()[:limit]


def parse_result(result, generic_name):
    details = {
        "generic_name": generic_name,
        "indications": clean_text(result.get("indications_and_usage")),
        "dosage": clean_text(result.get("dosage_and_administration")),
        "warnings": clean_text(result.get("warnings")),
        "contraindications": clean_text(result.get("contraindications")),
        "adverse_reactions": clean_text(result.get("adverse_reactions")),
        "drug_interactions": clean_text(result.get("drug_interactions")),
        "overdosage": clean_text(result.get("overdosage")),
        "pregnancy": clean_text(result.get("pregnancy")),
        "nursing_mothers": clean_text(result.get("nursing_mothers")),
        "pediatric_use": clean_text(result.get("pediatric_use")),
        "geriatric_use": clean_text(result.get("geriatric_use")),
        "how_supplied": clean_text(result.get("how_supplied")),
        "effective_time": clean_text(result.get("effective_time"), 64),
        "last_fetched": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }
    return details


def fetch_openfda(generic_name):
    generic_name = clean_text(generic_name, 160)
    if not generic_name or any(ord(character) < 32 for character in generic_name):
        return None

    variations = [generic_name]
    first_word = generic_name.split()[0]
    if first_word != generic_name:
        variations.append(first_word)
    variations.extend(
        {
            "perindopril arginine": ["perindopril"],
            "acetylsalicylic acid": ["aspirin"],
        }.get(generic_name.casefold(), [])
    )

    for variation in dict.fromkeys(variations):
        escaped = variation.replace("\\", "\\\\").replace('"', '\\"')
        query = urllib.parse.urlencode(
            {
                "search": f'openfda.generic_name:"{escaped}"',
                "limit": "1",
            }
        )
        url = f"https://{OPENFDA_HOST}/drug/label.json?{query}"
        request = urllib.request.Request(
            url,
            headers={
                "Accept": "application/json",
                "User-Agent": "Ryoku-MedKit-Guide/1.0",
            },
        )
        try:
            with OPENFDA.open(request, timeout=15) as response:
                if not openfda_url_allowed(response.geturl()):
                    continue
                length = response.headers.get("Content-Length")
                if length and int(length) > MAX_RESPONSE_BYTES:
                    continue
                payload = response.read(MAX_RESPONSE_BYTES + 1)
            if len(payload) > MAX_RESPONSE_BYTES:
                continue
            data = json.loads(payload.decode("utf-8"))
            results = data.get("results", [])
            if results and isinstance(results[0], dict):
                return parse_result(results[0], variation)
        except (
            OSError,
            TimeoutError,
            UnicodeDecodeError,
            ValueError,
            json.JSONDecodeError,
            urllib.error.URLError,
        ):
            continue
    return None


def cache_is_fresh(details, now, cache_days):
    last_fetched = details.get("last_fetched", "")
    if not isinstance(last_fetched, str) or not last_fetched:
        return False
    try:
        fetched = datetime.datetime.fromisoformat(last_fetched)
        if fetched.tzinfo is None:
            fetched = fetched.replace(tzinfo=datetime.timezone.utc)
        age = now - fetched
        return datetime.timedelta(0) <= age < datetime.timedelta(days=cache_days)
    except (TypeError, ValueError):
        return False


def safe_value(value, default, maximum):
    return clean_text(value, maximum) if isinstance(value, str) else default


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache-days", type=int, default=7)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--offline", action="store_true")
    return parser.parse_args()


def main():
    args = parse_args()
    cache_days = max(1, min(30, args.cache_days))
    medkit = load_json(MEDKIT_PATH)
    medicines = medkit.get("medicines") if isinstance(medkit, dict) else None
    if not isinstance(medicines, list):
        print(json.dumps({"error": "No medicines found", "medicines": {}}))
        return

    cache = load_json(CACHE_PATH)
    if not isinstance(cache, dict):
        cache = {"version": 1, "medicines": {}}
    cached_medicines = cache.get("medicines")
    if not isinstance(cached_medicines, dict):
        cached_medicines = {}

    now = datetime.datetime.now(datetime.timezone.utc)
    result = {"version": 1, "medicines": {}, "errors": []}
    for medicine in medicines[:MAX_MEDICINES]:
        if not isinstance(medicine, dict) or medicine.get("active", True) is False:
            continue
        name = safe_value(medicine.get("name"), "", 160)
        generic = safe_value(medicine.get("generic"), "", 160)
        if not name:
            continue

        cached = cached_medicines.get(name)
        if not isinstance(cached, dict):
            cached = {}
        details = cached.get("details")
        if not isinstance(details, dict):
            details = {}

        needs_fetch = args.force or not cache_is_fresh(details, now, cache_days)
        if needs_fetch and generic and not args.offline:
            fetched = fetch_openfda(generic)
            if fetched:
                details = fetched
            else:
                result["errors"].append(f"Could not refresh {name}")

        times = medicine.get("times")
        if not isinstance(times, list):
            times = []
        stock = medicine.get("stock", 0)
        refill_at = medicine.get("refill_at", 5)
        result["medicines"][name] = {
            "name": name,
            "dose": safe_value(medicine.get("dose"), "", 160),
            "times": [
                clean_text(value, 64) for value in times[:16] if isinstance(value, str)
            ],
            "stock": (
                stock
                if isinstance(stock, (int, float)) and not isinstance(stock, bool)
                else 0
            ),
            "refill_at": (
                refill_at
                if isinstance(refill_at, (int, float))
                and not isinstance(refill_at, bool)
                else 5
            ),
            "notes": safe_value(medicine.get("notes"), "", 2_000),
            "generic": generic,
            "missed_dose_note": safe_value(
                medicine.get("missed_dose_note"), "", 2_000
            ),
            "details": details,
        }

    new_cache = {
        "version": 1,
        "medicines": {
            name: {"details": medicine["details"]}
            for name, medicine in result["medicines"].items()
        },
    }
    save_json(CACHE_PATH, new_cache)
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()