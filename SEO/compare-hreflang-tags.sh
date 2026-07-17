```bash
#!/usr/bin/env bash

set -u

# ---------------------------------------------------------------------------
# Configuration
# Only adjust the values in this section.
# ---------------------------------------------------------------------------

PAGE_TYPE="Category"

OLD_SHOP_NAME="Old Shop"
OLD_URL="<url>"

NEW_SHOP_NAME="New Shop"
NEW_URL="<url>"

SEPARATOR_LENGTH=68

python3 - \
    "$PAGE_TYPE" \
    "$OLD_SHOP_NAME" \
    "$OLD_URL" \
    "$NEW_SHOP_NAME" \
    "$NEW_URL" \
    "$SEPARATOR_LENGTH" <<'PYTHON'
from __future__ import annotations

import subprocess
import sys
import tempfile
from collections import Counter
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlsplit, urlunsplit


(
    PAGE_TYPE,
    OLD_SHOP_NAME,
    OLD_URL,
    NEW_SHOP_NAME,
    NEW_URL,
    SEPARATOR_LENGTH_VALUE,
) = sys.argv[1:7]

SEPARATOR_LENGTH = int(SEPARATOR_LENGTH_VALUE)
SEPARATOR = "-" * SEPARATOR_LENGTH
HEADER_SEPARATOR = "=" * SEPARATOR_LENGTH


@dataclass
class FetchResult:
    requested_url: str
    final_url: str
    status: int
    body: str
    error: str = ""


class HreflangParser(HTMLParser):
    def __init__(self, base_url: str) -> None:
        super().__init__(convert_charrefs=True)
        self.base_url = base_url
        self.entries: list[tuple[str, str]] = []

    def handle_starttag(
        self,
        tag: str,
        attrs: list[tuple[str, str | None]],
    ) -> None:
        if tag.lower() != "link":
            return

        values = {
            name.lower(): (value or "").strip()
            for name, value in attrs
            if name
        }

        rel_values = {
            value.lower()
            for value in values.get("rel", "").split()
        }

        hreflang = values.get("hreflang", "")
        href = values.get("href", "")

        if "alternate" in rel_values and hreflang and href:
            self.entries.append(
                (
                    hreflang,
                    urljoin(self.base_url, href),
                )
            )


def fetch(url: str) -> FetchResult:
    with tempfile.NamedTemporaryFile(delete=False) as body_file:
        body_path = Path(body_file.name)

    try:
        process = subprocess.run(
            [
                "curl",
                "--silent",
                "--show-error",
                "--location",
                "--compressed",
                "--max-time",
                "20",
                "--user-agent",
                "Mozilla/5.0 SEO-Hreflang-Check/1.0",
                "--output",
                str(body_path),
                "--write-out",
                "%{http_code}\t%{url_effective}",
                url,
            ],
            capture_output=True,
            text=True,
            check=False,
        )

        body = body_path.read_text(
            encoding="utf-8",
            errors="replace",
        )

        metadata = process.stdout.strip().split("\t", 1)

        status = (
            int(metadata[0])
            if metadata and metadata[0].isdigit()
            else 0
        )

        final_url = (
            metadata[1]
            if len(metadata) == 2
            else url
        )

        return FetchResult(
            requested_url=url,
            final_url=final_url,
            status=status,
            body=body,
            error=process.stderr.strip(),
        )
    finally:
        body_path.unlink(missing_ok=True)


def parse_hreflang(
    document: str,
    base_url: str,
) -> list[tuple[str, str]]:
    parser = HreflangParser(base_url)
    parser.feed(document)

    return parser.entries


def normalize_url(url: str) -> str:
    parsed = urlsplit(url.strip())

    scheme = parsed.scheme.lower()
    hostname = (parsed.hostname or "").lower()
    port = parsed.port

    if port and not (
        (scheme == "http" and port == 80)
        or (scheme == "https" and port == 443)
    ):
        netloc = f"{hostname}:{port}"
    else:
        netloc = hostname

    return urlunsplit(
        (
            scheme,
            netloc,
            parsed.path or "/",
            parsed.query,
            "",
        )
    )


def result_text(value: bool) -> str:
    return "OK" if value else "ERROR"


def check_shop(
    shop_name: str,
    url: str,
) -> dict[str, object]:
    page = fetch(url)

    print(f"Shop:                         {shop_name}")
    print(f"Input URL:                    {url}")
    print(f"Final URL:                    {page.final_url}")
    print(f"HTTP status:                  {page.status}")

    if page.error:
        print(f"curl notice:                  {page.error}")

    if page.status < 200 or page.status >= 400:
        print("Result:                       URL NOT REACHABLE")
        print(SEPARATOR)

        return {
            "codes": set(),
            "ok": False,
        }

    entries = parse_hreflang(
        page.body,
        page.final_url,
    )

    codes = [
        code.lower()
        for code, _ in entries
    ]

    code_counts = Counter(codes)

    duplicate_codes = sorted(
        code
        for code, count in code_counts.items()
        if count > 1
    )

    print(f"Hreflang count:               {len(entries)}")

    if not entries:
        print("Hreflang entries:             NOT FOUND")
        print("Result:                       WARNING")
        print(SEPARATOR)

        return {
            "codes": set(),
            "ok": False,
        }

    print("Hreflang entries:")

    for code, href in entries:
        print(f"  {code:<12} -> {href}")

    target_results: list[dict[str, object]] = []
    current_url = normalize_url(page.final_url)
    self_referencing = False

    print("Target page checks:")

    for code, href in entries:
        target = fetch(href)
        target_final_url = normalize_url(target.final_url)

        if 200 <= target.status < 400:
            target_entries = parse_hreflang(
                target.body,
                target.final_url,
            )
        else:
            target_entries = []

        target_codes = {
            target_code.lower()
            for target_code, _ in target_entries
        }

        has_return_link = any(
            normalize_url(target_href) == current_url
            for _, target_href in target_entries
        )

        if target_final_url == current_url:
            self_referencing = True

        reachable = 200 <= target.status < 400

        target_results.append(
            {
                "code": code.lower(),
                "reachable": reachable,
                "return_link": has_return_link,
                "codes": target_codes,
            }
        )

        print(
            f"  {code:<12} "
            f"HTTP {target.status:<3} | "
            f"Return link: {result_text(has_return_link):<6} | "
            f"Final: {target.final_url}"
        )

    current_codes = set(codes)

    all_targets_reachable = all(
        bool(item["reachable"])
        for item in target_results
    )

    all_return_links = all(
        bool(item["return_link"])
        for item in target_results
    )

    same_code_set = all(
        item["codes"] == current_codes
        for item in target_results
        if item["reachable"]
    )

    no_duplicates = not duplicate_codes

    print(
        "Self-referencing:             "
        f"{result_text(self_referencing)}"
    )

    print(
        "All target pages reachable:  "
        f"{result_text(all_targets_reachable)}"
    )

    print(
        "Reciprocal return links:      "
        f"{result_text(all_return_links)}"
    )

    print(
        "Language codes consistent:   "
        f"{result_text(same_code_set)}"
    )

    print(
        "Duplicate language codes:    "
        + (
            "NONE"
            if no_duplicates
            else ", ".join(duplicate_codes)
        )
    )

    overall_ok = (
        self_referencing
        and all_targets_reachable
        and all_return_links
        and same_code_set
        and no_duplicates
    )

    print(
        "Overall result:               "
        f"{'OK' if overall_ok else 'WARNING'}"
    )

    print(SEPARATOR)

    return {
        "codes": current_codes,
        "ok": overall_ok,
    }


print()
print(HEADER_SEPARATOR)
print("Hreflang Tag Comparison")
print(f"Page type: {PAGE_TYPE}")
print(HEADER_SEPARATOR)
print()

old_result = check_shop(
    OLD_SHOP_NAME,
    OLD_URL,
)

new_result = check_shop(
    NEW_SHOP_NAME,
    NEW_URL,
)

old_codes = old_result["codes"]
new_codes = new_result["codes"]

print()
print("OLD / NEW COMPARISON")
print(SEPARATOR)

if old_codes == new_codes:
    print("Hreflang language codes:      IDENTICAL")
else:
    print("Hreflang language codes:      DIFFERENT")

    print(
        "Only in old shop:             "
        + (
            ", ".join(sorted(old_codes - new_codes))
            or "none"
        )
    )

    print(
        "Only in new shop:             "
        + (
            ", ".join(sorted(new_codes - old_codes))
            or "none"
        )
    )

print(
    "Old shop:                     "
    + ("OK" if old_result["ok"] else "WARNING")
)

print(
    "New shop:                     "
    + ("OK" if new_result["ok"] else "WARNING")
)

print(SEPARATOR)
PYTHON
```
