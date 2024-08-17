#!/bin/csh

# =================================================================================================
# Functions implemented:
#	- Download dataset from NCEP
# Script usage:
#   - ./download.csh 2024 02 01 2024 02 29 |& tee download.log
# Author information:
#	- Created by ZHANG Hua (zhangh20011114@gmail.com), 2024/6/16.
# =================================================================================================

# >>> Set wget option

# Experienced Wget Users: add additional command-line flags to 'opts' here
#   Use the -r (--recursive) option with care
#   Do NOT use the -b (--background) option - simultaneous file downloads
#       can cause your data access to be blocked
set opts = "-N"

# Check wget version.  Set the --no-check-certificate option 
# if wget version is 1.10 or higher
set v = `wget -V | grep 'GNU Wget ' | cut -d ' ' -f 3`
set a = `echo ${v} | cut -d '.' -f 1`
set b = `echo ${v} | cut -d '.' -f 2`
if (100 * ${a} + ${b} > 109) then
	set cert_opt = "--no-check-certificate"
else
	set cert_opt = ""
endif

# >>> Set output directory
set OUT_HOME = /work/share/ac4sj3muo0/data/wrfinput

# >>> Set dataset information
set dataset = ds083.2
set format  = grib2
set REMOTE_HOME = https://data.rda.ucar.edu/${dataset}/${format}

# >>> Set start date and end date
set year_start	= $argv[1]	# 2024
set month_start	= $argv[2]	# 02
set day_start	= $argv[3]	# 01
set year_end	= $argv[4]	# 2024
set month_end	= $argv[5]	# 02
set day_end		= $argv[6]	# 29

# >>> Set the hours for daily downloads
set hours = (00 06 12 18)

# DAY_MAX can be changed, and it serves to prevent
# the entry of many days by mistake.

set DAY_MAX = 31 # This can be changed

# >>> Echo start date and end date

set date_start = ${year_start}-${month_start}-${day_start}
set date_end   = ${year_end}-${month_end}-${day_end}

echo "Start date: ${date_start}"
echo "End   date: ${date_end}"

# >>> Test the number of days to be processed

@ DAY_NUM = (`date -ud ${date_end} +%s` - `date -ud ${date_start} +%s`) / 86400 + 1

if (${DAY_NUM} > ${DAY_MAX} || ${DAY_NUM} < 0) then
	echo "Error: The date is illegal."
	if (${DAY_NUM} > ${DAY_MAX}) then
		echo "Error: The number of days to be processed exceeds ${DAY_MAX}."
		exit 1
	else
		echo "Error: The end date precedes the start date."
		exit 1
	endif
endif

# >>> Download file daily cycle

set date_second_start = `date -ud ${date_start} +%s`
set date_second_end   = `date -ud ${date_end} +%s`

set date_second_now = ${date_second_start}
while (${date_second_now} <= ${date_second_end})
	
	set date_now = `date -ud @${date_second_now} +%Y-%m-%d`
	echo "Working date: ${date_now}"
	
	foreach hh (${hours})
		
		@ hour_second_now = ${date_second_now} + ${hh} * 3600
		
		set yyyy = `date -ud @${hour_second_now} +%Y`
		set yyyymm = `date -ud @${hour_second_now} +%Y.%m`
		set yyyymmdd = `date -ud @${hour_second_now} +%Y%m%d`
		set mm = `date -ud @${hour_second_now} +%m`
		
		set out_path = ${OUT_HOME}/${dataset}/${yyyy}/${mm}
		if (! -d ${out_path}) then
			mkdir -p ${out_path}
		endif
		
		set remote_path = ${REMOTE_HOME}/${yyyy}/${yyyymm}
		set filename = fnl_${yyyymmdd}_${hh}_00.${format}
		set syscmd = "wget -P ${out_path} ${cert_opt} ${opts} ${remote_path}/${filename}" 
		echo "${syscmd}"
		${syscmd}
		
	end
	
	@ date_second_now = ${date_second_now} + 24 * 3600
	
end

echo "Successfully download all files!"
