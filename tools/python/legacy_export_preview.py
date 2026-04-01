from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: python legacy_export_preview.py /path/to/export.json")
        return 1

    path = Path(sys.argv[1]).expanduser()
    payload = json.loads(path.read_text(encoding="utf-8"))

    if isinstance(payload, list):
        items = payload
        rules = []
    else:
        items = payload.get("items", [])
        rules = payload.get("categoryRules", [])

    print(f"items: {len(items)}")
    print(f"category rules: {len(rules)}")

    domains = {}
    for item in items:
        domain = item.get("domain") or "unknown"
        domains[domain] = domains.get(domain, 0) + 1

    top_domains = sorted(domains.items(), key=lambda entry: entry[1], reverse=True)[:10]
    if top_domains:
        print("top domains:")
        for domain, count in top_domains:
            print(f"  {domain}: {count}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
