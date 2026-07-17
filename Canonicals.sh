#!/usr/bin/env bash

# Nur diese drei Werte anpassen:
PAGE_TYPE="Kategorie"
OLD_URL="https://www.rohde.com/damen/hausschuhe/"
NEW_URL="https://rohde-shoes-integration.scalecommerce.cloud/Damen/Hausschuhe/"

check_canonical() {
    local shop="$1"
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

    curl_result=$(curl \
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

    echo "Shop:              $shop"
    echo "Eingegebene URL:   $url"
    echo "Finale URL:        $final_url"
    echo "HTTP-Status:       $http_status"

    if [[ "$http_status" -lt 200 || "$http_status" -ge 400 ]]; then
        echo "Canonical:         NICHT GEPRÜFT"
        echo "Bewertung:         URL NICHT ERREICHBAR"
        echo "------------------------------------------------------------"

        rm -f "$html_file" "$headers_file"
        return
    fi

    IFS=$'\t' read -r canonical_count canonical_url canonical_status < <(
        python3 - "$html_file" "$final_url" <<'PYTHON'
import html
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlsplit, urlunsplit

html_file = Path(sys.argv[1])
final_url = sys.argv[2]
document = html_file.read_text(encoding="utf-8", errors="replace")


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
                html.unescape(href.strip())
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

    return urlunsplit((
        scheme,
        netloc,
        path,
        parsed.query,
        ""
    ))


parser = CanonicalParser()
parser.feed(document)

canonicals = parser.canonicals
count = len(canonicals)

if count == 0:
    print("0\tNICHT VORHANDEN\tFEHLT")
    sys.exit(0)

canonical = canonicals[0]

if count > 1:
    status = "MEHRFACH VORHANDEN"
elif normalize_url(canonical) == normalize_url(final_url):
    status = "SELBSTREFERENZIEREND"
else:
    status = "ABWEICHEND"

print(f"{count}\t{canonical}\t{status}")
PYTHON
    )

    echo "Canonical-Anzahl: $canonical_count"
    echo "Canonical-URL:    $canonical_url"

    case "$canonical_status" in
        "SELBSTREFERENZIEREND")
            echo "Bewertung:         OK – selbstreferenzierend"
            ;;
        "MEHRFACH VORHANDEN")
            echo "Bewertung:         FEHLER – mehrere Canonicals vorhanden"
            ;;
        "FEHLT")
            echo "Bewertung:         PRÜFEN – kein Canonical vorhanden"
            ;;
        *)
            echo "Bewertung:         PRÜFEN – Canonical weicht von der finalen URL ab"
            ;;
    esac

    echo "------------------------------------------------------------"

    rm -f "$html_file" "$headers_file"
}

echo
echo "============================================================"
echo "Canonical-Prüfung"
echo "Seitentyp: $PAGE_TYPE"
echo "============================================================"
echo

check_canonical "ALTER SHOP" "$OLD_URL"
check_canonical "NEUER SHOP" "$NEW_URL"