#!/usr/bin/env bash
# Catalogue integrity check for ryostore.
#
# The Hub fetches this repo at runtime and the actuator installs straight from
# it, so a dangling reference reaches a user as a failed install: a bundle item
# pointing at a plugin/pack/installer that is not here, a manifest whose scripts
# do not exist on disk, an unknown item type or `requires` the shell cannot act
# on, or malformed JSON. This catches all of that before anything ships. Run it
# before a push; CI runs it too.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

errors=0
err() {
	printf 'FAIL: %s\n' "$1" >&2
	errors=$((errors + 1))
}

# a registry (jq path like .plugins / .packs) contains an entry with this id.
registry_has() {
	jq -e --arg id "$2" "$1 | any(.id == \$id)" "$3" >/dev/null 2>&1
}

# 1. every JSON in the catalogue parses.
for dir in bundles plugins nautilus livewalls colorschemes; do
	[ -d "$dir" ] || continue
	while IFS= read -r f; do
		jq -e . "$f" >/dev/null 2>&1 || err "invalid JSON: $f"
	done < <(find "$dir" -name '*.json' -type f)
done

# 2. bundles: registry entry -> bundle.json, and every item resolves.
if [ -f bundles/registry.json ]; then
	while IFS= read -r id; do
		[ -n "$id" ] || continue
		bf="bundles/$id/bundle.json"
		[ -f "$bf" ] || {
			err "bundle '$id' listed in registry has no $bf"
			continue
		}
		jq -e --arg id "$id" '.id == $id' "$bf" >/dev/null 2>&1 ||
			err "$bf: id does not match '$id'"

		while IFS= read -r req; do
			[ -n "$req" ] || continue
			case "$req" in
			multilib | cachyos | gpu-lib32) ;;
			*) err "$bf: unknown requires '$req' (the shell cannot enable it)" ;;
			esac
		done < <(jq -r '.requires[]? // empty' "$bf")

		while IFS= read -r asset; do
			[ -n "$asset" ] || continue
			[ -f "bundles/$id/$asset" ] || err "$bf: missing image asset '$asset'"
		done < <(jq -r '([.preview] + (.screenshots // [])) | .[]? // empty' "$bf")

		while IFS=$'\t' read -r itype iname; do
			[ -n "$iname" ] || continue
			case "$itype" in
			plugin)
				registry_has '.plugins' "$iname" plugins/registry.json ||
					err "$bf: plugin '$iname' is not in plugins/registry.json"
				[ -f "plugins/$iname/manifest.json" ] ||
					err "$bf: plugin '$iname' has no plugins/$iname/manifest.json"
				;;
			nautilus-pack)
				registry_has '.packs' "$iname" nautilus/registry.json ||
					err "$bf: nautilus-pack '$iname' is not in nautilus/registry.json"
				[ -f "nautilus/$iname/manifest.json" ] ||
					err "$bf: nautilus-pack '$iname' has no nautilus/$iname/manifest.json"
				;;
			script)
				[ -f "bundles/$id/installers/$iname.sh" ] ||
					err "$bf: script '$iname' has no bundles/$id/installers/$iname.sh"
				;;
			package) ;;
			*) err "$bf: unknown item type '$itype' (item '$iname')" ;;
			esac
		done < <(jq -r '.items[] | "\(.type)\t\(.name)"' "$bf")
	done < <(jq -r '.bundles[].id' bundles/registry.json)
fi

# 3. plugin registry entries resolve to a dir + matching manifest.
if [ -f plugins/registry.json ]; then
	while IFS=$'\t' read -r id path; do
		[ -n "$id" ] || continue
		[ -f "$path/manifest.json" ] || {
			err "plugin '$id': $path/manifest.json missing"
			continue
		}
		jq -e --arg id "$id" '.id == $id' "$path/manifest.json" >/dev/null 2>&1 ||
			err "$path/manifest.json: id does not match '$id'"
	done < <(jq -r '.plugins[] | "\(.id)\t\(.path)"' plugins/registry.json)
fi

# 4. nautilus packs: manifest and the scripts on disk agree, both ways.
if [ -f nautilus/registry.json ]; then
	while IFS=$'\t' read -r id path; do
		[ -n "$id" ] || continue
		m="$path/manifest.json"
		[ -f "$m" ] || {
			err "nautilus '$id': $m missing"
			continue
		}
		jq -e --arg id "$id" '.id == $id' "$m" >/dev/null 2>&1 ||
			err "$m: id does not match '$id'"
		while IFS= read -r s; do
			[ -n "$s" ] || continue
			[ -f "$path/scripts/$s" ] || err "$m: lists script '$s' with no file in $path/scripts/"
		done < <(jq -r '.scripts[]? // empty' "$m")
		if [ -d "$path/scripts" ]; then
			while IFS= read -r f; do
				base=$(basename "$f")
				jq -e --arg s "$base" '.scripts | index($s)' "$m" >/dev/null 2>&1 ||
					err "$m: script '$base' on disk is not listed in scripts[]"
				[ -x "$f" ] || err "$path/scripts/$base is not executable"
			done < <(find "$path/scripts" -maxdepth 1 -type f)
		fi
	done < <(jq -r '.packs[] | "\(.id)\t\(.path)"' nautilus/registry.json)
fi

# 5. installers are runnable.
while IFS= read -r f; do
	[ -x "$f" ] || err "$f is not executable"
	head -n1 "$f" | grep -q '^#!' || err "$f has no shebang"
done < <(find installers bundles -type f \( -path 'installers/*.sh' -o -path '*/installers/*.sh' \))

# 6. Migrated categories activate the common Store contract independently.
for category in rices lockscreens plugins bundles barstyles fastfetch decors launcher-images fastfetch-emblems vesktop-themes; do
	[ -f "$category/registry.json" ] || continue
	python3 tests/validate-store.py --root . --categories "$category" ||
		err "$category Store product validation failed"
done

if [ "$errors" -gt 0 ]; then
	printf '\n%d catalogue error(s) found.\n' "$errors" >&2
	exit 1
fi
printf 'catalogue OK: every bundle item, manifest, and installer resolves.\n'
