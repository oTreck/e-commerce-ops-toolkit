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
NEW_URL="<url>""

SEPARATOR="------------------------------------------------------------"

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

check_canonical() {
    local shop_name="$1"
    local url="$2"

    local html_file
    local headers_file
    local curl_result
    local http_status
    local final_url
    local canonical_count
    local canonical_url
    local canonical_status

    html_file=$(mktemp)
    headers_file=$(mktemp)

    cleanup() {
        rm -f "$html_file" "$headers_file"
    }

    curl_result=$(
        curl \
            --silent \
            --show-error \
            --location \
            --dump-header "$headers_file" \
            --output "$html_file" \
            --write-out "%{http_code}|%{url_effective}" \
            "$url"
    )

    http_status="${curl_result%%|*}"
    final_url="${curl_result#*|}"

    echo "Shop:              $shop_name"
    echo "Input URL:         $url"
    echo "Final URL:         $final_url"
    echo "HTTP status:       $http_status"

    if [[ "$http_status" -lt 200 || "$http_status" -ge 400 ]]; then
        echo "Canonical:         NOT CHECKED"
        echo "Result:            URL NOT REACHABLE"
        echo "$SEPARATOR"

        cleanup
        return
    fi

    IFS=$'\t' read -r \
        canonical_count \
        canonical_url \
        canonical_status < <(
            python3 - "$html_file" "$final_url" <<'PYTHON'
import html
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlsplit, urlunsplit


html_file = Path(sys.argv[1])
final_url = sys.argv[2]

document = html_file.read_text(
    encoding="utf-8",
    errors="replace",
)


class CanonicalParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.canonicals = []

    def handle_starttag(self, tag, attrs):
        if tag.lower() != "link":
            return

        attributes = {
            str(name).lower(): value
            for name, value in attrs
            if name
        }

        rel_values = {
            value.lower()
            for value in (attributes.get("rel") or "").split()
        }

        href = attributes.get("href")

        if "canonical" in rel_values and href:
            absolute_url = urljoin(
                final_url,
                html.unescape(href.strip()),
            )

            self.canonicals.append(absolute_url)


def normalize_url(url):
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

    path = parsed.path or "/"

    return urlunsplit(
        (
            scheme,
            netloc,
            path,
            parsed.query,
            "",
        )
    )


parser = CanonicalParser()
parser.feed(document)

canonicals = parser.canonicals
canonical_count = len(canonicals)

if canonical_count == 0:
    print("0\tNOT FOUND\tMISSING")
    sys.exit(0)

canonical_url = canonicals[0]

if canonical_count > 1:
    canonical_status = "MULTIPLE"
elif normalize_url(canonical_url) == normalize_url(final_url):
    canonical_status = "SELF_REFERENCING"
else:
    canonical_status = "DIFFERENT"

print(
    f"{canonical_count}\t"
    f"{canonical_url}\t"
    f"{canonical_status}"
)
PYTHON
        )

    echo "Canonical count:   $canonical_count"
    echo "Canonical URL:     $canonical_url"

    case "$canonical_status" in
        "SELF_REFERENCING")
            echo "Result:            OK - canonical is self-referencing"
            ;;
        "MULTIPLE")
            echo "Result:            ERROR - multiple canonical tags found"
            ;;
        "MISSING")
            echo "Result:            WARNING - no canonical tag found"
            ;;
        "DIFFERENT")
            echo "Result:            WARNING - canonical differs from final URL"
            ;;
        *)
            echo "Result:            ERROR - unknown canonical status"
            ;;
    esac

    echo "$SEPARATOR"

    cleanup
}

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

echo
echo "============================================================"
echo "Canonical Tag Comparison"
echo "Page type: $PAGE_TYPE"
echo "============================================================"
echo

check_canonical "$OLD_SHOP_NAME" "$OLD_URL"
check_canonical "$NEW_SHOP_NAME" "$NEW_URL"