#!/bin/bash
###
 # @Author       : ZHANG Hua (zhangh23@mails.tsinghua.edu.cn)
 # @Date         : 2025-12-30 12:09:32
 # @LastEditors  : ZHANG Hua (zhangh23@mails.tsinghua.edu.cn)
 # @LastEditTime : 2025-12-30 16:32:23
 # @Description  : Download data from Geoscience Data Exchange (GDEX)
 # @Usage        : ./download.sh <dataset_type> <start_year> <start_month> <start_day> <end_year> <end_month> <end_day>
 # 
 # Copyright (c) 2025 by ZHANG Hua, All Rights Reserved. 
### 

# -----------------------------------------------------------------------------
# Set download configuration
# -----------------------------------------------------------------------------

# Set the output directory
OUTPUT_HOME="/work/share/ac4sj3muo0/data/wrfinput"

# Set the remote base URL
REMOTE_BASE_URL="https://osdf-director.osg-htc.org/ncar/gdex"

# Set dataset type
DATASET_TYPE=$1; shift # e.g., "ds461.0", "ds094.0", "ds083.2"

# Set dataset-specific parameters
case ${DATASET_TYPE} in
    "ds461.0")
        TIME_RESOLUTION=6
        LOCAL_DIR_TEMPLATE="${OUTPUT_HOME}/${DATASET_TYPE}/\${YYYY}/\${MM}"
        REMOTE_URL_TEMPLATE="${REMOTE_BASE_URL}/d461000/little_r/\${YYYY}/SURFACE_OBS:\${YYYY}\${MM}\${DD}\${HH}"
        ;;
    "ds094.0")
        TIME_RESOLUTION=24
        LOCAL_DIR_TEMPLATE="${OUTPUT_HOME}/${DATASET_TYPE}/\${YYYY}/\${MM}/\${DD}"
        REMOTE_URL_TEMPLATE="${REMOTE_BASE_URL}/d094000/\${YYYY}/cdas1.\${YYYY}\${MM}\${DD}.pgrbh.tar"
        ;;
    "ds083.2")
        TIME_RESOLUTION=6
        LOCAL_DIR_TEMPLATE="${OUTPUT_HOME}/${DATASET_TYPE}/\${YYYY}/\${MM}"
        REMOTE_URL_TEMPLATE="${REMOTE_BASE_URL}/d083002/grib2/\${YYYY}/\${YYYY}.\${MM}/fnl_\${YYYY}\${MM}\${DD}_\${HH}_00.grib2"
        ;;
    *)
        echo "Error: Unsupported dataset type '${DATASET_TYPE}'"
        exit 1
        ;;
esac

# Maximum days allowed (prevents accidental large downloads)
MAX_DAY=31

# -----------------------------------------------------------------------------
# Load shared functions and initialize
# -----------------------------------------------------------------------------
source ${HOME}/zhangh/scripts/share/dld.sh "$@"

# -----------------------------------------------------------------------------
# Function: build_file_paths
# Description: Build local directory and remote URL for current timestamp
# Sets: LOCAL_DIR, REMOTE_URL
# -----------------------------------------------------------------------------
build_file_paths() {
    eval "LOCAL_DIR=\"${LOCAL_DIR_TEMPLATE}\""
    eval "REMOTE_URL=\"${REMOTE_URL_TEMPLATE}\""
}

# -----------------------------------------------------------------------------
# Execute download
# -----------------------------------------------------------------------------
run_download_loop

