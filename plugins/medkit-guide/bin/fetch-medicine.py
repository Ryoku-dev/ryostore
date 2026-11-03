#!/usr/bin/env python3
"""Fetch medicine details from OpenFDA and cache locally."""
import json, os, sys, urllib.request, urllib.parse, datetime

MEDKIT_PATH = os.path.expanduser("~/.local/share/medkit/medicines.json")
CACHE_PATH = os.path.expanduser("~/.local/share/ryoku/plugins/medkit-guide/medicine-cache.json")
CACHE_TTL_DAYS = 7

def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except:
        return None

def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def fetch_openfda(generic_name):
    """Fetch medicine details from OpenFDA API. Try multiple name variations."""
    if not generic_name:
        return None
    
    # Try multiple variations
    variations = [generic_name]
    # Add first word
    first_word = generic_name.split()[0]
    if first_word != generic_name:
        variations.append(first_word)
    # Common alternatives
    alternatives = {
        "perindopril arginine": ["perindopril"],
        "acetylsalicylic acid": ["aspirin"],
    }
    if generic_name in alternatives:
        variations.extend(alternatives[generic_name])
    
    for var in variations:
        encoded = urllib.parse.quote(var)
        url = f"https://api.fda.gov/drug/label.json?search=openfda.generic_name:\"{encoded}\"&limit=1"
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'MedKit-Guide/1.0'})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode())
            if 'results' in data and data['results']:
                r = data['results'][0]
                # ... rest of parsing
                return parse_result(r, var)
        except:
            continue
    return None

def parse_result(r, generic_name):
    """Parse OpenFDA result into details dict."""
    def get_field(key):
        val = r.get(key, [])
        if isinstance(val, list) and val:
            return val[0]
        return val if val else ""
    
    details = {
        "generic_name": generic_name,
        "indications": get_field('indications_and_usage'),
        "dosage": get_field('dosage_and_administration'),
        "warnings": get_field('warnings'),
        "contraindications": get_field('contraindications'),
        "adverse_reactions": get_field('adverse_reactions'),
        "drug_interactions": get_field('drug_interactions'),
        "overdosage": get_field('overdosage'),
        "pregnancy": get_field('pregnancy'),
        "nursing_mothers": get_field('nursing_mothers'),
        "pediatric_use": get_field('pediatric_use'),
        "geriatric_use": get_field('geriatric_use'),
        "how_supplied": get_field('how_supplied'),
        "effective_time": r.get('effective_time', ''),
        "last_fetched": datetime.datetime.now().isoformat(),
    }
    
    for key in details:
        if isinstance(details[key], str):
            details[key] = details[key].replace('<br>', '\n').replace('<br/>', '\n').replace('<br />', '\n')
            import re
            details[key] = re.sub(r'<[^>]+>', '', details[key])
            details[key] = details[key].strip()
    
    return details

def main():
    # Load MedKit medicines
    medkit = load_json(MEDKIT_PATH)
    if not medkit or 'medicines' not in medkit:
        print(json.dumps({"error": "No medicines found", "medicines": []}))
        return
    
    # Load cache
    cache = load_json(CACHE_PATH) or {"version": 1, "medicines": {}}
    
    # Check if cache is stale
    now = datetime.datetime.now()
    result = {"version": 1, "medicines": {}, "errors": []}
    
    for med in medkit['medicines']:
        if not med.get('active', True):
            continue
        
        name = med['name']
        generic = med.get('generic', '')
        
        # Check cache
        cached = cache.get('medicines', {}).get(name, {})
        last_fetched = cached.get('details', {}).get('last_fetched', '')
        
        needs_fetch = True
        if last_fetched:
            try:
                fetch_date = datetime.datetime.fromisoformat(last_fetched)
                if (now - fetch_date).days < CACHE_TTL_DAYS:
                    needs_fetch = False
            except:
                pass
        
        if needs_fetch and generic:
            print(f"Fetching {name} ({generic})...", file=sys.stderr)
            details = fetch_openfda(generic)
            if details:
                cached['details'] = details
            else:
                result['errors'].append(f"Failed to fetch {name}")
                cached['details'] = cached.get('details', {})
        else:
            if not cached.get('details'):
                cached['details'] = {}
        
        # Build result entry
        result['medicines'][name] = {
            "name": name,
            "dose": med.get('dose', ''),
            "times": med.get('times', []),
            "stock": med.get('stock', 0),
            "refill_at": med.get('refill_at', 5),
            "notes": med.get('notes', ''),
            "generic": generic,
            "missed_dose_note": med.get('missed_dose_note', ''),
            "details": cached.get('details', {}),
        }
    
    # Save cache
    cache['medicines'] = {}
    for name, data in result['medicines'].items():
        cache['medicines'][name] = {"details": data['details']}
    save_json(CACHE_PATH, cache)
    
    # Output result
    print(json.dumps(result, ensure_ascii=False))

if __name__ == "__main__":
    main()
