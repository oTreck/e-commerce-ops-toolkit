#!/usr/bin/env bash

# Nur diese drei Werte anpassen:
PAGE_TYPE="Detail"
OLD_URL="https://www.rohde.com/Damen/Hausschuhe/CALMYS-N-15.html"
NEW_URL="https://rohde-shoes-integration.scalecommerce.cloud/Damen/Hausschuhe/CALMYS-N-15.html"

extract_meta() {
    local prefix="$1"
    local shop="$2"
    local url="$3"
    local html_file
    local status
    local title
    local description
    local robots

    html_file=$(mktemp)

    status=$(curl \
        --silent \
        --show-error \
        --location \
        --output "$html_file" \
        --write-out "%{http_code}" \
        "$url"
    )

    if [[ "$status" == "200" ]]; then
        title=$(perl -0777 -ne '
            if (m{<title[^>]*>(.*?)</title>}is) {
                $value = $1;
                $value =~ s/<[^>]+>//g;
                $value =~ s/\s+/ /g;
                $value =~ s/^\s+|\s+$//g;
                print $value;
            }
        ' "$html_file")

        description=$(perl -0777 -ne '
            if (m{
                <meta\b
                (?=[^>]*\bname\s*=\s*["\x27]description["\x27])
                [^>]*>
            }isx) {
                $tag = $&;

                if ($tag =~ m{
                    \bcontent\s*=\s*(["\x27])(.*?)\1
                }isx) {
                    $value = $2;
                    $value =~ s/\s+/ /g;
                    $value =~ s/^\s+|\s+$//g;
                    print $value;
                }
            }
        ' "$html_file")

        robots=$(perl -0777 -ne '
            if (m{
                <meta\b
                (?=[^>]*\bname\s*=\s*["\x27]robots["\x27])
                [^>]*>
            }isx) {
                $tag = $&;

                if ($tag =~ m{
                    \bcontent\s*=\s*(["\x27])(.*?)\1
                }isx) {
                    $value = $2;
                    $value =~ s/\s+/ /g;
                    $value =~ s/^\s+|\s+$//g;
                    print $value;
                }
            }
        ' "$html_file")
    fi

    printf -v "${prefix}_STATUS" "%s" "$status"
    printf -v "${prefix}_TITLE" "%s" "${title:-NICHT VORHANDEN}"
    printf -v "${prefix}_DESCRIPTION" "%s" "${description:-NICHT VORHANDEN}"
    printf -v "${prefix}_ROBOTS" "%s" "${robots:-NICHT VORHANDEN}"

    echo "Shop:              $shop"
    echo "URL:               $url"
    echo "HTTP-Status:       $status"
    echo "Meta-Title:        ${title:-NICHT VORHANDEN}"
    echo "Meta-Description:  ${description:-NICHT VORHANDEN}"
    echo "Meta-Robots:       ${robots:-NICHT VORHANDEN}"
    echo "------------------------------------------------------------"

    rm -f "$html_file"
}

compare_value() {
    local label="$1"
    local old_value="$2"
    local new_value="$3"

    if [[ "$old_value" == "$new_value" ]]; then
        echo "$label: IDENTISCH"
    else
        echo "$label: ABWEICHEND"
    fi
}

echo
echo "============================================================"
echo "Seitentyp: $PAGE_TYPE"
echo "============================================================"
echo

extract_meta "OLD" "ALTER SHOP" "$OLD_URL"
extract_meta "NEW" "NEUER SHOP" "$NEW_URL"

echo
echo "ERGEBNIS"
echo "------------------------------------------------------------"

compare_value "Meta-Title" "$OLD_TITLE" "$NEW_TITLE"
compare_value "Meta-Description" "$OLD_DESCRIPTION" "$NEW_DESCRIPTION"

if [[ "${OLD_ROBOTS,,}" == "${NEW_ROBOTS,,}" ]]; then
    echo "Meta-Robots: IDENTISCH"
else
    echo "Meta-Robots: ABWEICHEND"
fi

echo "------------------------------------------------------------"