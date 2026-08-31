#!/bin/bash
###
 # @Author       : ZHANG Hua (zhangh23@mails.tsinghua.edu.cn)
 # @Date         : 2026-08-31 22:19:32
 # @LastEditors  : ZHANG Hua (zhangh23@mails.tsinghua.edu.cn)
 # @LastEditTime : 2026-09-01 02:02:43
 # @Description  : Download data from Geoscience Data Exchange (GDEX) through Globus Transfer Service (GridFTP)
 # @Usage        : ./download.sh <dataset_type> <start_year> <start_month> <start_day> <end_year> <end_month> <end_day>
 # 
 # Copyright (c) 2026 by ZHANG Hua, All Rights Reserved. 
### 

# -----------------------------------------------------------------------------
# Set download configuration
# -----------------------------------------------------------------------------

# Set the output directory
OUTPUT_HOME="/work/share/ac4sj3muo0/data/wrfinput"

# Set the globus and globusconnectpersonal executable paths
alias globus="/work/home/tsinghuazhangh/zhangh/software/install/apps/anaconda3/2023.07-2/bin/globus"
alias globusconnectpersonal="/work/home/tsinghuazhangh/zhangh/software/install/apps/gcp/3.3.0/globusconnectpersonal"

# Set the source and destination globus collection IDs
SRC_ID="c4e40965-a024-43d7-bef4-6010f3731b61"
DST_ID="1e9cffed-a566-11f1-a476-0afff7074b21"

# Set the batch file path
FILELIST_FILE="filelist.txt"

# Set dataset type
DATASET_TYPE=$1; shift # e.g., "ds461.0", "ds094.0", "ds083.2"

# Set dataset-specific parameters
case ${DATASET_TYPE} in
    "ds461.0")
        TIME_RESOLUTION=6
        SRC_FILE_TEMPLATE="/d461000/little_r/\${YYYY}/SURFACE_OBS:\${YYYY}\${MM}\${DD}\${HH}"
        DST_FILE_TEMPLATE="${OUTPUT_HOME}/${DATASET_TYPE}/\${YYYY}/\${MM}/SURFACE_OBS:\${YYYY}\${MM}\${DD}\${HH}"
        ;;
    "ds094.0")
        TIME_RESOLUTION=24
        SRC_FILE_TEMPLATE="/d094000/\${YYYY}/cdas1.\${YYYY}\${MM}\${DD}.pgrbh.tar"
        DST_FILE_TEMPLATE="${OUTPUT_HOME}/${DATASET_TYPE}/\${YYYY}/\${MM}/cdas1.\${YYYY}\${MM}\${DD}.pgrbh.tar"
        ;;
    "ds083.2")
        TIME_RESOLUTION=6
        SRC_FILE_TEMPLATE="/d083002/grib2/\${YYYY}/\${YYYY}.\${MM}/fnl_\${YYYY}\${MM}\${DD}_\${HH}_00.grib2"
        DST_FILE_TEMPLATE="${OUTPUT_HOME}/${DATASET_TYPE}/\${YYYY}/\${MM}/fnl_\${YYYY}\${MM}\${DD}_\${HH}_00.grib2"
        ;;
    *)
        echo "Error: Unsupported dataset type '${DATASET_TYPE}'"
        exit 1
        ;;
esac

# Maximum days allowed (prevents accidental large downloads)
MAX_DAY=36

# -----------------------------------------------------------------------------
# Function: parse_date_args
# Description: Parse command line arguments into start/end dates
# Arguments: $1-$3: start year, month, day
#            $4-$6: end year, month, day
# Returns: 0 on success, 1 on failure
# -----------------------------------------------------------------------------
parse_date_args() {
    if [[ $# -ne 6 ]]; then
        echo "Usage: ./download.sh <dataset_type> <start_year> <start_month> <start_day> <end_year> <end_month> <end_day>"
        return 1
    fi
    
    START_DATE="$1-$2-$3"
    END_DATE="$4-$5-$6"
    
    echo "Start date: ${START_DATE}"
    echo "End   date: ${END_DATE}"
}

# -----------------------------------------------------------------------------
# Function: validate_date_range
# Description: Check if date range is valid and within MAX_DAY limit
# Globals: START_DATE, END_DATE, MAX_DAY (default: 36)
# Returns: 0 on success, 1 on failure
# -----------------------------------------------------------------------------
validate_date_range() {
    : "${MAX_DAY:=36}"
    
    local start_sec end_sec num_days
    start_sec=$(date -ud "${START_DATE}" +%s)
    end_sec=$(date -ud "${END_DATE}" +%s)
    num_days=$(( (end_sec - start_sec) / 86400 + 1 ))
    
    if (( num_days > MAX_DAY )); then
        echo "Error: Number of days (${num_days}) exceeds limit (${MAX_DAY})."
        return 1
    elif (( num_days < 0 )); then
        echo "Error: End date precedes start date."
        return 1
    fi
    
    echo "Total days: ${num_days}"
}

# -----------------------------------------------------------------------------
# Function: init_time_loop
# Description: Initialize time loop variables (in seconds since epoch)
# Globals: START_DATE, END_DATE
# Sets: START_TIME, END_TIME, CURR_TIME
# -----------------------------------------------------------------------------
init_time_loop() {
    START_TIME=$(date -ud "${START_DATE}" +%s)
    END_TIME=$(date -ud "${END_DATE}" +%s)
    CURR_TIME=${START_TIME}
}

# -----------------------------------------------------------------------------
# Function: get_date_components
# Description: Extract date components from current timestamp
# Globals: CURR_TIME
# Sets: YYYY, JJJ, MM, DD, HH
# -----------------------------------------------------------------------------
get_date_components() {
    YYYY=$(date -ud @${CURR_TIME} +%Y)
    MM=$(date -ud @${CURR_TIME} +%m)
    DD=$(date -ud @${CURR_TIME} +%d)
    HH=$(date -ud @${CURR_TIME} +%H)
    echo "Processing: ${YYYY}-${MM}-${DD}_${HH}:00:00"
}

# -----------------------------------------------------------------------------
# Function: advance_time
# Description: Increment current time by specified hours
# Arguments: $1 - hours to advance
# Globals: CURR_TIME
# -----------------------------------------------------------------------------
advance_time() {
    local hours="$1"
    (( CURR_TIME += hours * 3600 ))
}

# -----------------------------------------------------------------------------
# Function: build_file_paths
# Description: Build source and destination file paths for current timestamp
#              and append them to the batch filelist
# Sets: SRC_FILE, DST_FILE
# -----------------------------------------------------------------------------
build_file_paths() {
    eval "SRC_FILE=\"${SRC_FILE_TEMPLATE}\""
    eval "DST_FILE=\"${DST_FILE_TEMPLATE}\""
    echo "${SRC_FILE} ${DST_FILE}" >> "${FILELIST_FILE}"
}

# -----------------------------------------------------------------------------
# Function: batch_transfer
# Description: Submit a batch transfer from the filelist
# Returns: 0 on success, 1 on failure
# -----------------------------------------------------------------------------
batch_transfer() {
    local cmd="globus transfer ${SRC_ID} ${DST_ID} --batch ${FILELIST_FILE} --notify off"
    local status task_id
    
    echo "${cmd}"
    task_id="$(${cmd} 2>&1 | tee /dev/tty | awk '/Task ID:/ {print $3}')"
    if [[ -n "${task_id}" ]]; then
        globus task wait "${task_id}"
        status=$?
        return ${status}
    else
        echo "Error: Failed to submit transfer task"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Function: download
# Description: Generate the batch filelist from the time range, then submit a
#              single batch transfer
# Requires: TIME_RESOLUTION (hours), build_file_paths function
# Note: build_file_paths must set SRC_FILE and DST_FILE
# -----------------------------------------------------------------------------
download() {
    TOTAL_FILES=0
    > "${FILELIST_FILE}" # Overwrite the existing filelist

    while (( CURR_TIME <= END_TIME )); do
        get_date_components
        build_file_paths
        (( TOTAL_FILES++ ))
        advance_time "${TIME_RESOLUTION}"
    done

    globusconnectpersonal -start &
    sleep 5 # Wait for Globus Connect Personal to connect online

    batch_transfer
    local status=$?
    globusconnectpersonal -stop

    echo "=========================================="
    if (( status == 0 )); then
        echo "All ${TOTAL_FILES} files downloaded successfully!"
    else
        echo "Batch transfer failed, see output above."
    fi
    echo "=========================================="
    return ${status}
}

# -----------------------------------------------------------------------------
# Function: init_downloader
# Description: Main initialization - setup parse args, validate, init loop
# Arguments: Command line arguments (date range)
# Returns: 0 on success, 1 on failure
# -----------------------------------------------------------------------------
init_downloader() {
    parse_date_args "$@" || return 1
    validate_date_range || return 1
    init_time_loop
}

# -----------------------------------------------------------------------------
# Auto-initialize when sourced with sufficient arguments
# -----------------------------------------------------------------------------
if [[ $# -eq 6 ]]; then
    init_downloader "$@"
fi

# -----------------------------------------------------------------------------
# Execute download
# -----------------------------------------------------------------------------
download
