```bash
#!/usr/bin/env bash

set -u

# ---------------------------------------------------------------------------
# Configuration
# Only adjust the values in this section.
# ---------------------------------------------------------------------------

PAGE_TYPE="Product Detail"

OLD_SHOP_NAME="Old Shop"
OLD_URL="<url>"

NEW_SHOP_NAME="New Shop"
NEW_URL="<url>"

SEPARATOR="------------------------------------------------------------"
HEADER_SEPARATOR="============================================================"

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

extract_meta() {
    local prefix="$1"
    local shop_name="$2"
    local url="$3"

    local html_file
    local curl_result
    local http_status
    local final_url
    local title=""
    local description=""
    local robots=""

    html_file=$(mktemp)

    curl_result=$(
        curl \
            --silent \
            --show-error \
            --location \
            --compressed \
            --max-time 20 \
            --user-agent "Mozilla/5.0 SEO-Meta-Check/1.0" \
            --output "$html_file" \
            --write-out "%{http_code}|%{url_effective}" \
            "$url"
    )

    http_status="${curl_result%%|*}"
    final_url="${curl_result#*|}"

    if [[ "$http_status" -ge 200 && "$http_status" -lt 400 ]]; then
        IFS=$'\t' read -r title description robots < <(
            python3 - "$html_file" <<'PYTHON'
import html
import sys
from html.parser import HTMLParser
from pathlib import Path


html_file = Path(sys.argv[1])
document = html_file.read_text(
    encoding="utf-8",
    errors="replace",
)


def clean_text(value: str) -> str:
    return " ".join(html.unescape(value).split())


class MetaParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.inside_title = False
        self.title_parts: list[str] = []
        self.description = ""
        self.robots = ""

    def handle_starttag(
        self,
        tag: str,
        attrs: list[tuple[str, str | None]],
    ) -> None:
        tag = tag.lower()

        if tag == "title":
            self.inside_title = True
            return

        if tag != "meta":
            return

        attributes = {
            name.lower(): (value or "").strip()
            for name, value in attrs
            if name
        }

        name = attributes.get("name", "").lower()
        content = clean_text(attributes.get("content", ""))

        if name == "description" and not self.description:
            self.description = content

        if name == "robots" and not self.robots:
            self.robots = content

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "title":
            self.inside_title = False

    def handle_data(self, data: str) -> None:
        if self.inside_title:
            self.title_parts.append(data)

    @property
    def title(self) -> str:
        return clean_text(" ".join(self.title_parts))


parser = MetaParser()
parser.feed(document)

title = parser.title or "NOT FOUND"
description = parser.description or "NOT FOUND"
robots = parser.robots or "NOT FOUND"

print(
    f"{title}\t"
    f"{description}\t"
    f"{robots}"
)
PYTHON
        )
    else
        title="NOT CHECKED"
        description="NOT CHECKED"
        robots="NOT CHECKED"
    fi

    printf -v "${prefix}_STATUS" "%s" "$http_status"
    printf -v "${prefix}_FINAL_URL" "%s" "$final_url"
    printf -v "${prefix}_TITLE" "%s" "$title"
    printf -v "${prefix}_DESCRIPTION" "%s" "$description"
    printf -v "${prefix}_ROBOTS" "%s" "$robots"

    echo "Shop:              $shop_name"
    echo "Input URL:         $url"
    echo "Final URL:         $final_url"
    echo "HTTP status:       $http_status"
    echo "Meta title:        $title"
    echo "Meta description:  $description"
    echo "Meta robots:       $robots"

    if [[ "$http_status" -lt 200 || "$http_status" -ge 400 ]]; then
        echo "Result:            URL NOT REACHABLE"
    fi

    echo "$SEPARATOR"

    rm -f "$html_file"
}


compare_value() {
    local label="$1"
    local old_value="$2"
    local new_value="$3"

    if [[ "$old_value" == "$new_value" ]]; then
        echo "$label: IDENTICAL"
    else
        echo "$label: DIFFERENT"
        echo "  Old: $old_value"
        echo "  New: $new_value"
    fi
}


compare_case_insensitive() {
    local label="$1"
    local old_value="$2"
    local new_value="$3"

    if [[ "${old_value,,}" == "${new_value,,}" ]]; then
        echo "$label: IDENTICAL"
    else
        echo "$label: DIFFERENT"
        echo "  Old: $old_value"
        echo "  New: $new_value"
    fi
}

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------

echo
echo "$HEADER_SEPARATOR"
echo "Meta Tag Comparison"
echo "Page type: $PAGE_TYPE"
echo "$HEADER_SEPARATOR"
echo

extract_meta \
    "OLD" \
    "$OLD_SHOP_NAME" \
    "$OLD_URL"

extract_meta \
    "NEW" \
    "$NEW_SHOP_NAME" \
    "$NEW_URL"

echo
echo "OLD / NEW COMPARISON"
echo "$SEPARATOR"

compare_value \
    "HTTP status" \
    "$OLD_STATUS" \
    "$NEW_STATUS"

compare_value \
    "Meta title" \
    "$OLD_TITLE" \
    "$NEW_TITLE"

compare_value \
    "Meta description" \
    "$OLD_DESCRIPTION" \
    "$NEW_DESCRIPTION"

compare_case_insensitive \
    "Meta robots" \
    "$OLD_ROBOTS" \
    "$NEW_ROBOTS"

echo "$SEPARATOR"
```
