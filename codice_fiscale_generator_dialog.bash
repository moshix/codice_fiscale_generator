#!/bin/bash
# Copyright 2025 by moshix
# Generator using the dialog utility (if this is  your thing)
# July 2025 / Milan

set -e

# Check if dialog is available
if ! command -v dialog &> /dev/null; then
    echo "Error: This script requires 'dialog' to be installed."
    echo "On macOS: brew install dialog"
    echo "On Ubuntu/Debian: sudo apt-get install dialog"
    echo "On RHEL/CentOS: sudo yum install dialog"
    exit 1
fi

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Set dialog colors
export DIALOGRC=$(mktemp)
cat > "$DIALOGRC" << 'EOF'
use_colors = ON
screen_color = (CYAN,BLACK,ON)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (BLACK,WHITE,OFF)
title_color = (BLUE,WHITE,ON)
border_color = (WHITE,WHITE,ON)
button_active_color = (WHITE,BLUE,ON)
button_inactive_color = (BLACK,WHITE,OFF)
button_key_active_color = (WHITE,BLUE,ON)
button_key_inactive_color = (RED,WHITE,OFF)
button_label_active_color = (YELLOW,BLUE,ON)
button_label_inactive_color = (BLACK,WHITE,ON)
inputbox_color = (BLACK,WHITE,OFF)
inputbox_border_color = (BLACK,WHITE,OFF)
searchbox_color = (BLACK,WHITE,OFF)
searchbox_title_color = (BLUE,WHITE,ON)
searchbox_border_color = (WHITE,WHITE,ON)
position_indicator_color = (BLUE,WHITE,ON)
menubox_color = (BLACK,WHITE,OFF)
menubox_border_color = (WHITE,WHITE,ON)
item_color = (BLACK,WHITE,OFF)
item_selected_color = (WHITE,BLUE,ON)
tag_color = (BLUE,WHITE,ON)
tag_selected_color = (YELLOW,BLUE,ON)
tag_key_color = (RED,WHITE,OFF)
tag_key_selected_color = (RED,BLUE,ON)
check_color = (BLACK,WHITE,OFF)
check_selected_color = (WHITE,BLUE,ON)
uarrow_color = (GREEN,WHITE,ON)
darrow_color = (GREEN,WHITE,ON)
itemhelp_color = (WHITE,BLACK,OFF)
form_active_text_color = (WHITE,BLUE,ON)
form_text_color = (WHITE,CYAN,ON)
form_item_readonly_color = (CYAN,WHITE,ON)
EOF

comuni_file=$(mktemp)
local_country_file="./countries.json"

# Cleanup function
cleanup() {
    rm -f "$comuni_file" "$DIALOGRC"
}
trap cleanup EXIT

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

show_intro() {
    dialog --title "Codice Fiscale Generator" \
           --colors \
           --msgbox "\n\Z4Welcome to the Italian Codice Fiscale Generator!\Zn\n\n\
This program will guide you through generating your Italian tax code.\n\n\
You will be asked for the following information:\n\n\
\Z2• Last Name\Zn\n\
\Z2• First Name\Zn\n\
\Z2• Date of Birth (YYYY-MM-DD format)\Zn\n\
\Z2• Gender (M for Male, F for Female)\Zn\n\
\Z2• Birth Location (Italian comune or foreign country)\Zn\n\n\
\Z1Press OK to continue...\Zn" 18 60
}

show_progress() {
    local step="$1"
    local total="$2"
    local message="$3"
    
    local percent=$((step * 100 / total))
    echo "$percent" | dialog --title "Progress" \
                            --colors \
                            --gauge "\Z6$message\Zn" 8 60 0
}

get_user_input() {
    # Show progress
    show_progress 1 6 "Downloading comuni data..."
    
    # Download comuni codes
    if ! curl -s -o "$comuni_file" https://raw.githubusercontent.com/matteocontrini/comuni-json/master/comuni.json; then
        dialog --title "Error" --colors --msgbox "\Z1Failed to download comuni list.\Zn\n\nPlease check your internet connection." 8 50
        exit 1
    fi

    if [[ ! -s "$comuni_file" ]]; then
        dialog --title "Error" --colors --msgbox "\Z1Failed to download comuni list.\Zn\n\nThe downloaded file is empty." 8 50
        exit 1
    fi

    if [[ ! -f "$local_country_file" ]]; then
        dialog --title "Error" --colors --msgbox "\Z1Missing countries.json file!\Zn\n\nPlease ensure countries.json is in the same folder as this script." 8 60
        exit 1
    fi

    # Get Last Name
    show_progress 2 6 "Getting personal information..."
    while true; do
        lastname=$(dialog --title "Personal Information" \
                         --colors \
                         --inputbox "\Z4Enter your Last Name:\Zn" 8 50 3>&1 1>&2 2>&3)
        
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
        
        if [[ -n "$lastname" ]]; then
            break
        fi
        
        dialog --title "Error" --colors --msgbox "\Z1Last name is required.\Zn" 6 40
    done

    # Get First Name
    show_progress 3 6 "Getting personal information..."
    while true; do
        firstname=$(dialog --title "Personal Information" \
                          --colors \
                          --inputbox "\Z4Enter your First Name:\Zn" 8 50 3>&1 1>&2 2>&3)
        
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
        
        if [[ -n "$firstname" ]]; then
            break
        fi
        
        dialog --title "Error" --colors --msgbox "\Z1First name is required.\Zn" 6 40
    done

    # Get Date of Birth
    show_progress 4 6 "Getting birth information..."
    while true; do
        dob=$(dialog --title "Birth Information" \
                    --colors \
                    --inputbox "\Z4Enter your Date of Birth:\Zn\n\n\Z2Format: YYYY-MM-DD\Zn\n\Z2Example: 1990-12-25\Zn" 10 50 3>&1 1>&2 2>&3)
        
        if [[ $? -ne 0 ]]; then
            exit 1
        fi
        
        if validate_date "$dob"; then
            break
        fi
        
        dialog --title "Error" --colors --msgbox "\Z1Invalid date format.\Zn\n\nPlease use YYYY-MM-DD format\n(e.g., 1990-12-25)" 8 40
    done

    # Get Gender
    show_progress 5 6 "Getting gender information..."
    gender=$(dialog --title "Gender Selection" \
                   --colors \
                   --menu "\Z4Select your gender:\Zn" 12 50 4 \
                   "M" "Male" \
                   "F" "Female" 3>&1 1>&2 2>&3)
    
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    # Get Birth Location
    show_progress 6 6 "Getting birth location..."
    born_in_italy=$(dialog --title "Birth Location" \
                          --colors \
                          --menu "\Z4Were you born in Italy?\Zn" 10 50 4 \
                          "Y" "Yes - Born in Italy" \
                          "N" "No - Born abroad" 3>&1 1>&2 2>&3)
    
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    if [[ "$born_in_italy" == "Y" ]]; then
        while true; do
            birthplace=$(dialog --title "Italian Birth Location" \
                              --colors \
                              --inputbox "\Z4Enter the Italian comune of birth:\Zn\n\n\Z2Example: Milano, Roma, Napoli\Zn" 10 50 3>&1 1>&2 2>&3)
            
            if [[ $? -ne 0 ]]; then
                exit 1
            fi
            
            place_code=$(lookup_place_code "$birthplace")
            
            if [[ -n "$place_code" && "$place_code" != "null" ]]; then
                break
            fi
            
            dialog --title "Error" --colors --msgbox "\Z1Italian comune '$birthplace' not found.\Zn\n\nPlease check the spelling and try again." 8 50
        done
    else
        while true; do
            country=$(dialog --title "Foreign Birth Location" \
                            --colors \
                            --inputbox "\Z4Enter your Country of Birth:\Zn\n\n\Z2Example: Francia, Germania, Spagna\Zn" 10 50 3>&1 1>&2 2>&3)
            
            if [[ $? -ne 0 ]]; then
                exit 1
            fi
            
            place_code=$(lookup_foreign_country_code "$country")
            
            if [[ -n "$place_code" && "$place_code" != "null" ]]; then
                break
            fi
            
            dialog --title "Error" --colors --msgbox "\Z1Country '$country' not found.\Zn\n\nPlease check the spelling and try again." 8 50
        done
    fi
}

generate_and_show_result() {
    # Generate Codice Fiscale
    cf_surname=$(get_surname_code "$lastname")
    cf_name=$(get_name_code "$firstname")
    cf_date=$(get_date_code "$dob" "$gender")

    cf15="${cf_surname}${cf_name}${cf_date}${place_code}"
    cf16=$(calculate_check_character "$cf15")
    cf="${cf15}${cf16}"

    # Show result
    dialog --title "Your Codice Fiscale" \
           --colors \
           --msgbox "\n\Z4Generated Codice Fiscale:\Zn\n\n\
\Z2$cf\Zn\n\n\
\Z6Details:\Zn\n\
Last Name: $lastname\n\
First Name: $firstname\n\
Date of Birth: $dob\n\
Gender: $gender\n\
Birth Location: $([ "$born_in_italy" == "Y" ] && echo "$birthplace" || echo "$country")\n\n\
\Z1Press OK to finish.\Zn" 16 60
}

main() {
    # Clear screen and show intro
    clear
    printf "${CYAN}%s${NC}\n" "Codice Fiscale Generator - Loading..."
    
    show_intro
    
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    get_user_input
    generate_and_show_result
    
    clear
    printf "${GREEN}%s${NC}\n" "✓ Codice Fiscale generated successfully!"
    printf "${WHITE}%s${NC}\n" "Your Codice Fiscale: ${YELLOW}$cf${NC}"
    printf "${CYAN}%s${NC}\n" "Thank you for using the Codice Fiscale Generator!"
}

# Run main function
main

