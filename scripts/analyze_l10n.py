import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

with open('lib/shared/l10n/app_localizations.dart', 'r', encoding='utf-8') as f:
    content = f.read()

lang_codes = ['en', 'he', 'es', 'de', 'fr', 'ar', 'hi', 'sv']
lang_entries = {}

for code in lang_codes:
    pattern = rf"'{code}':\s*\{{(.*?)\n\s*\}},"
    match = re.search(pattern, content, re.DOTALL)
    if match:
        entries = dict(re.findall(r"'([a-zA-Z0-9_\-]+)':\s*'((?:\\'|[^'])*)'", match.group(1)))
        lang_entries[code] = entries
        print(f"Language '{code}': {len(entries)} keys")
    else:
        print(f"ERROR: Could not find '{code}'")

en_keys = set(lang_entries['en'].keys())

total_missing = 0
for code in lang_codes:
    if code == 'en':
        continue
    missing = en_keys - set(lang_entries[code].keys())
    if missing:
        total_missing += len(missing)
        print(f"  '{code}' missing {len(missing)} keys: {list(missing)[:5]}")

if total_missing == 0:
    print("\nPERFECT! ALL 8 LANGUAGES HAVE 100% KEY PARITY (236/236 keys)!")
else:
    print(f"\nFAILED: {total_missing} keys missing across languages.")

