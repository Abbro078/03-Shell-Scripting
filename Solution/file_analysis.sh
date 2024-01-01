#!/bin/bash

display_help() {
    echo -e "Usage: bash file_analysis.sh [directory_path] [filter1] [filter2] ...\n"
    echo -e "What it does: Searches for files in the given directory and its subdirectories. Generates a comprehensive report with file details such as size, owner, permissions, and last modified timestamp.\n"
    echo -e "The report will be saved in a file named 'file_analysis.txt'.\n"
    echo -e "Filter Options:"
    echo -e "-e [extensions]: Filter files by extensions (comma-separated, e.g., txt,sh)"
    echo -e "+s [size]: Gives files that are larger than size (in bytes)"
    echo -e "-s [size]: Gives files that are smaller than size (in bytes)"
    echo -e "-t [start_timestamp:end_timestamp]: Filter files by last modified timestamp (in format: YYYY-MM-DD)"
    echo -e "-p [permissions]: Filter files by permissions (in format: e.g. -rw-rw-r--)\n"
    echo -e "Example: bash file_analysis.sh /path/to/directory -e txt,odt -s 10000\n"
}

validate_directory() {
    if [ ! -d "$1" ]; then
        echo "Error: Directory '$1' does not exist."
        exit 1
    fi
}

analyze_file() {
    local file="$1"
    local report="$2"
    shift 2

    size=$(du -b "$file" | awk '{print $1}')
    owner=$(stat -c "%U" "$file")
    file_permissions=$(stat -c "%A" "$file")
    last_modified=$(stat -c "%y" "$file")

    while [ $# -gt 0 ]; do
        filter="$1"
        case $filter in
            -e)
                filter_value="${2}"
                file_extension="${file##*.}"
                if [[ ",$filter_value," == *",$file_extension,"* ]]; then
                    shift 2
                else
                    return 0
                fi
                ;;
            +s)
                filter_value="${2}"
                if [ "$size" -gt "$filter_value" ]; then
                    shift 2
                else
                    return 0
                fi
                ;;
            -s)
                filter_value="${2}"
                if [ "$size" -lt "$filter_value" ]; then
                    shift 2
                else
                    return 0
                fi
                ;;
            -t)
                filter_value="${2}"
                start_timestamp=$(date -d "$(echo "$filter_value" | cut -d':' -f1)" +%s)
                end_timestamp=$(date -d "$(echo "$filter_value" | cut -d':' -f2)" +%s)
                file_timestamp=$(date -d "$last_modified" +%s)
                if [ "$file_timestamp" -ge "$start_timestamp" ] && [ "$file_timestamp" -le "$end_timestamp" ]; then
                    shift 2
                else
                    return 0
                fi
                ;;
            -p)
                filter_value="${2}"
                if [ "$file_permissions" = "$filter_value" ]; then
                    shift 2
                else
                    return 0
                fi
                ;;
            *)
                return 1
                ;;
        esac
    done

    echo -e "$file:$size:$owner:$file_permissions:$last_modified" >> "$report"
}

sort_files_by_owner_and_size() {
    local temp_file="$1"
    local current_owner=""
    sort -t: -k3,3 -k2,2n "$temp_file" | while IFS=: read -r file size owner permissions last_modified; do
        if [ "$current_owner" != "$owner" ]; then
            current_owner="$owner"
            printf "\nOwner of the files below: %-10s\n" "$owner"
        fi
        printf "File: %-30s \nSize: %10s bytes \nPermissions: %-10s \nLast Modified: %s\n\n" "$file" "$size" "$permissions" "$last_modified"
    done
}

perform_file_analysis() {
    local directory="$1"
    local report="file_analysis.txt"
    local temp_file=$(mktemp)

    echo "Performing file analysis..."

    validate_directory "$directory"

    find "$directory" -type f -print0 | while IFS= read -r -d '' file; do
        analyze_file "$file" "$temp_file" "${@:2}" || continue
    done

    echo "File Analysis Report" > "$report"
    echo "" >> "$report"
    sort_files_by_owner_and_size "$temp_file" >> "$report"

    rm "$temp_file"

    echo "File analysis completed. Report saved in '$report'."
}

generate_summary_report() {
    local report="$1"
    local total_files=$(grep -c "^File:" "$report")
    local total_size=$(awk -F: '{sum += $2} END {print sum}' "$report")

    echo "Summary Report" >> "$report"
    echo "" >> "$report"
    echo "Total Files: $total_files" >> "$report"
    echo "Total Size: $total_size bytes" >> "$report"
}

if [ $# -ge 1 ]; then
    if [[ "$1" = "--help" || "$1" = "-h" ]]; then
        display_help
        exit 0
    fi

    directory="$1"
    perform_file_analysis "$directory" "${@:2}"
    generate_summary_report "file_analysis.txt"
else
    echo "Error: Invalid number of arguments."
    echo "Use 'bash file_analysis.sh --help or -h' for more information."
    exit 1
fi