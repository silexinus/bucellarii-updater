#!/bin/bash

# Updater for the bucellarii-class programs
# The user wouldn't need to know that this program exists. They'd only interact with this program indirectly,
#   by doing commands like this:
#   $:tachibana --update
#   which means, tachibana first attempts to download this script, or if it exists it tells it to update itself.
#   Then, tachibana calls this script again and tells it to update tachibana. Then, updater compares the local tachibana
#   version with the one from github and downloads the file if an update is possible

updatername="bucellariiupdater"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fileversions="${script_dir}/.versions_bucellarii.txt"

# Configuration: Map program names to their GitHub URLs
# Format: [name]="script_url|versions_url"
declare -A PROGRAMS=(
    [bucellariiupdater]="https://raw.githubusercontent.com/silexinus/bucellarii-updater/main/bucellarii-updater.sh|https://raw.githubusercontent.com/silexinus/bucellarii-updater/main/.versions_bucellarii.txt"
    [tachibana]="https://raw.githubusercontent.com/silexinus/tachibana/main/tachibana.sh|https://raw.githubusercontent.com/silexinus/tachibana/main/.versions_bucellarii.txt"
    [bynneops]="https://raw.githubusercontent.com/silexinus/bynneops/main/bynneops.jl|https://raw.githubusercontent.com/silexinus/bynneops/main/.versions_bucellarii.txt"
)

# Takes a program `tag' (such as tachibana or bucellariiupdater)
#   and returns the script's filename (this includes the extension,
#   as this information is needed for the downloading function)
getprogramfilename() {
    local programname="$1"
    local url="${PROGRAMS[$programname]%%|*}"  # Get first URL (before the |)
    basename "$url"                            # Extract filename
}

# Download with 20-second timeout
download_with_timeout() {
    local url="$1"
    local output="$2"
    local timeout="${3:-20}" # Default value is 20 seconds, but you can pass another value
    # here1 let the bucellarii-class programs have a flag that overrides this 20-second default value. Then, bucellarii-updater would have to weave this value into the workflow

    timeout "$timeout" curl -fsSL "$url" -o "$output" 2>/dev/null || \
    timeout "$timeout" wget -q "$url" -O "$output" 2>/dev/null || \
    return 1
}

# Compare semver strings (e.g., "1.3.1" vs "1.2.5")
# Returns: 0 if equal, 1 if first > second, 2 if first < second
compare_semver() {
    local v1="$1"
    local v2="$2"

    # Split into arrays
    local IFS='.'
    local -a v1_parts=($v1)
    local -a v2_parts=($v2)

    for i in {0..2}; do
        local part1=${v1_parts[$i]:-0}
        local part2=${v2_parts[$i]:-0}

        if (( part1 > part2 )); then
            return 1
        elif (( part1 < part2 )); then
            return 2
        fi
    done

    return 0
}

# Get local version from fileversions
get_local_version() {
    local programname="$1"

    if [[ ! -f "$fileversions" ]]; then
        echo "NOT_FOUND"
        return 1
    fi

    local line=$(grep "^${programname} " "$fileversions" | head -1)
    if [[ -z "$line" ]]; then
        echo "NOT_FOUND"
        return 1
    fi

    echo "${line#* }" # Returns the second word from the string (drops the program name, so only the semver value remains)
}

# Get GitHub version from .versions_bucellarii.txt
get_github_version() {
    local programname="$1"
    local versions_url="$2"
    local temp_file=$(mktemp)

    if ! download_with_timeout "$versions_url" "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi

    local line=$(grep "^${programname} " "$temp_file" | head -1)
    rm -f "$temp_file"

    if [[ -z "$line" ]]; then
        return 1
    fi

    echo "${line#* }"
}

# Check version without updating
handle_compareversion() {
    local programname="$1"

    if [[ -z "${PROGRAMS[$programname]}" ]]; then
        echo "ERROR! Program '$programname' not configured." >&2
        return 1
    fi

    local urls="${PROGRAMS[$programname]}"
    local versions_url="${urls##*|}"

    local local_ver=$(get_local_version "$programname")
    if [[ "$local_ver" == "NOT_FOUND" ]]; then
        # Extra space on these so the local semver value is aligned with the github one
        echo "Local version:  NOT INSTALLED"
    else
        echo "Local version:  $local_ver"
    fi

    local github_ver=$(get_github_version "$programname" "$versions_url")
    if [[ $? -eq 0 ]]; then
        echo "GitHub version: $github_ver"
    else
        echo "GitHub version: NETWORK UNAVAILABLE"
    fi
}

save_bucellariiscript_toscriptfolder() {
    local script_dir="$1"
    local programname="$2"
    local temp_script="$3"
    local fileversions="$4"
    local github_ver="$5"

    # Move to destination
    local dest_path="${script_dir}/$(getprogramfilename "$programname")"
    mv "$temp_script" "$dest_path"
    chmod u+x "$dest_path"

    # Update version file
    if [[ ! -f "$fileversions" ]]; then
        touch "$fileversions"
    fi

    # Remove old entry if exists
    grep -v "^${programname} " "$fileversions" > "${fileversions}.tmp"
    mv "${fileversions}.tmp" "$fileversions"

    # Add new entry
    echo "$programname $github_ver" >> "$fileversions"

    # Only print this for programs other than bucellarii-updater
    if [[ "$programname" != "bucellariiupdater" ]]; then
        echo "Successfully updated $programname to version $github_ver"
    fi
    return 0
}

# Update a program
handle_update() {
    local programname="$1"

    if [[ -z "${PROGRAMS[$programname]}" ]]; then
        echo "ERROR! Program '$programname' not configured." >&2
        return 1
    fi

    local urls="${PROGRAMS[$programname]}"
    local script_url="${urls%|*}"
    local versions_url="${urls##*|}"

    echo "Checking for updates to $programname..."

    # Get GitHub version
    local github_ver=$(get_github_version "$programname" "$versions_url")
    if [[ $? -ne 0 ]]; then
        echo "ERROR! Could not reach GitHub to compare version." >&2
        return 1
    fi

    # Get local version
    local local_ver=$(get_local_version "$programname")
    if [[ "$local_ver" == "NOT_FOUND" ]]; then
        echo "Program not installed locally. Installing version $github_ver..."
        local should_download=1
    else
        compare_semver "$github_ver" "$local_ver"
        local cmp=$?

        if [[ $cmp -eq 1 ]]; then
            echo "Update available: $local_ver → $github_ver"
            local should_download=1
        elif [[ $cmp -eq 0 ]]; then
            echo "Already up to date (version $local_ver)"
            return 0
        else
            echo "Local version is newer than GitHub version ($local_ver > $github_ver)"
            return 0
        fi
    fi

    # Download the script
    if [[ $should_download -eq 1 ]]; then
        local temp_script=$(mktemp)
        if ! download_with_timeout "$script_url" "$temp_script" 20; then
            echo "ERROR! Failed to download script from GitHub." >&2
            rm -f "$temp_script"
            return 1
        fi

        save_bucellariiscript_toscriptfolder "$script_dir" "$programname" "$temp_script" "$fileversions" "$github_ver"

        return 0
    fi
}

# Self-update mode
handle_selfupdate() {
    local temp_script=$(mktemp)
    local urls="${PROGRAMS[$updatername]}"
    local script_url="${urls%|*}"
    local versions_url="${urls##*|}"
    if ! download_with_timeout "$script_url" "$temp_script" 20; then
        echo -e "ERROR! Failed to download updater script from GitHub.\nCheck your connection and try again." >&2
        rm -f "$temp_script"
        return 1
    fi

    # Get GitHub version
    local github_ver=$(get_github_version "$updatername" "$versions_url")
    if [[ $? -ne 0 ]]; then
        echo "ERROR! Could not reach GitHub." >&2
        return 1
    fi

    save_bucellariiscript_toscriptfolder "$script_dir" "$updatername" "$temp_script" "$fileversions" "$github_ver"
    return 0
}

# Main
main() {
    if [[ $# -lt 1 ]]; then
        cat >&2 << EOF
Usage: $0 [--compare-version|--update|--self-update] <program_name>

Examples:
  $0 --compare-version tachibana
  $0 --update messerbild
  $0 --self-update
EOF
        return 1
    fi

    local mode="$1"
    local programname="$2"

    case "$mode" in
        --compare-version)
            if [[ -z "$programname" ]]; then
                echo "ERROR! --compare-version requires a program name." >&2
                return 1
            fi
            handle_compareversion "$programname"
            ;;
        --update)
            if [[ -z "$programname" ]]; then
                echo "ERROR! --update requires a program name." >&2
                return 1
            fi
            handle_update "$programname"
            ;;
        --self-update)
            handle_selfupdate
            ;;
        *)
            echo "ERROR! Unknown mode: $mode" >&2
            return 1
            ;;
    esac
}

main "$@"
