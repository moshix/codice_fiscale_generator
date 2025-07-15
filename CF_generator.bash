#!/bin/bash
# codice fiscale generator, copyright 2025 by moshix
# License: GPLv3. All rights reserved. 
# July 2025 / Milan

set -e

comuni_file=$(mktemp)
local_country_file="./countries.json"

# === Download comuni codes ===
echo "Downloading comuni list..."
curl -s -o "$comuni_file" https://raw.githubusercontent.com/matteocontrini/comuni-json/master/comuni.json

if [[ ! -s "$comuni_file" ]]; then
    echo "Failed to download comuni list."
    exit 1
fi

if [[ ! -f "$local_country_file" ]]; then
    echo "Missing countries.json file in the same folder!"
    exit 1
fi

# === Helper functions ===
consonants() {
    echo "$1" | tr -d 'aeiouAEIOU' | tr -d ' ' | tr '[:lower:]' '[:upper:]'
}

vowels() {
    echo "$1" | tr -cd 'aeiouAEIOU' | tr '[:lower:]' '[:upper:]'
}

pad_cf_part() {
    local val="$1"
    while [ ${#val} -lt 3 ]; do
        val="${val}X"
    done
    echo "$val"
}

get_surname_code() {
    local s="$1"
    local cons=$(consonants "$s")
    local vow=$(vowels "$s")
    local code=$(echo "${cons}${vow}" | cut -c1-3)
    pad_cf_part "$code"
}

get_name_code() {
    local s="$1"
    local cons=$(consonants "$s")
    if [ ${#cons} -ge 4 ]; then
        code="${cons:0:1}${cons:2:1}${cons:3:1}"
    else
        local vow=$(vowels "$s")
        code=$(echo "${cons}${vow}" | cut -c1-3)
    fi
    pad_cf_part "$code"
}

get_date_code() {
    local dob="$1"
    local gender="$2"

    local year=$(echo "$dob" | cut -d'-' -f1 | tail -c 3)
    local month_num=$(echo "$dob" | cut -d'-' -f2)
    local day=$(echo "$dob" | cut -d'-' -f3)

    local month_codes=(A B C D E H L M P R S T)
    local month_code="${month_codes[$((10#$month_num - 1))]}"

    if [[ "$gender" =~ [Ff] ]]; then
        day=$((10#$day + 40))
    fi

    printf "%s%s%02d" "$year" "$month_code" "$day"
}

lookup_place_code() {
    local place="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    jq -r --arg place "$place" '
        .[] | select((.nome | ascii_downcase) == $place) | .codiceCatastale
    ' "$comuni_file"
}

lookup_foreign_country_code() {
    local country="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    jq -r --arg country "$country" '
        .[] | select((.nome | ascii_downcase) == $country) | .codiceCatastale
    ' "$local_country_file"
}

validate_date() {
    [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1

    # macOS-compatible first, GNU fallback
    if date -jf "%Y-%m-%d" "$1" "+%Y-%m-%d" >/dev/null 2>&1; then
        return 0
    elif date -d "$1" +%F >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

calculate_check_character() {
    local cf15="$1"
    local odd_table=(1 0 5 7 9 13 15 17 19 21 2 4 18 20 11 3 6 8 12 14 16 10 22 25 24 23)
    local even_table=(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25)

    local total=0
    for ((i=0; i<15; i++)); do
        char=${cf15:$i:1}
        ascii=$(printf "%d" "'$char")
        index=$(( ascii >= 65 ? ascii - 65 : ascii - 48 )) # A-Z or 0-9
        if (( i % 2 == 0 )); then
            total=$((total + odd_table[index]))
        else
            total=$((total + even_table[index]))
        fi
    done

    local remainder=$((total % 26))
    printf "%c" $((remainder + 65))
}

# === Input ===
read -p "Enter Last Name: " lastname
[[ -z "$lastname" ]] && echo "Last name is required." && exit 1

read -p "Enter First Name: " firstname
[[ -z "$firstname" ]] && echo "First name is required." && exit 1

read -p "Enter Date of Birth (YYYY-MM-DD): " dob
if ! validate_date "$dob"; then
    echo "Invalid date format. Use YYYY-MM-DD."
    exit 1
fi

read -p "Enter Gender (M/F): " gender
if ! [[ "$gender" =~ ^[MmFf]$ ]]; then
    echo "Gender must be M or F."
    exit 1
fi

read -p "Were you born in Italy? (Y/N): " born_in_italy
if [[ "$born_in_italy" =~ ^[Yy]$ ]]; then
    read -p "Enter Italian comune of birth: " birthplace
    place_code=$(lookup_place_code "$birthplace")
else
    read -p "Enter Country of Birth: " country
    place_code=$(lookup_foreign_country_code "$country")
fi

if [[ -z "$place_code" || "$place_code" == "null" ]]; then
    echo "Error: Location not found."
    exit 1
fi

# === Generate Codice Fiscale ===
cf_surname=$(get_surname_code "$lastname")
cf_name=$(get_name_code "$firstname")
cf_date=$(get_date_code "$dob" "$gender")

cf15="${cf_surname}${cf_name}${cf_date}${place_code}"
cf16=$(calculate_check_character "$cf15")
cf="${cf15}${cf16}"

echo "Codice Fiscale: $cf"

# === Cleanup ===
rm -f "$comuni_file"

