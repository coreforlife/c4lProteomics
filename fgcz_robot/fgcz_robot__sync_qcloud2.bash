#!/bin/bash
# 
# Synchronises Mass Spectrometric (MS) Quality Control (QC) data to CRG.ES
#
# the code is trigged by using cron. A cron entry (crontab) on 
# our system look like that:
# 47 */7 * * *  (/home/cpanse/__checkouts/c4lProteomics/fgcz_robot/fgcz_robot__sync_qcloud2.bash | lftp qcloud-ext@perelman.crg.es)
#
# Author: Christian Panse <cp@fgcz.ethz.ch>, 2019
#
# Requirements:
#   linux, lftp, cron
#   keep FTP authentifications in ~/.netrc file
#
# Usage:
#   fgcz_robot__sync_qcloud2.bash | qcloud-ext@perelman.crg.es

set -o pipefail

scriptname=$(basename $0)
lock="/tmp/${scriptname}"
exec 200>$lock
flock -n 200 || exit 1

#######################################
# instrument to labsysid linkage
# given by <roger.olivella@crg.eu>
#######################################
declare -A labsysid=(["QEXACTIVEHF_2"]="41102513-a4c3-4e23-9a05-3151620a7c8c"
  ["LUMOS_1"]="a905ed8a-19a3-4c74-ac47-0d663219e54d"
  ["FUSION_2"]="4764a3a7-30c8-407d-a70e-1a5eb7685a41"
  ["LUMOS_2"]="35a9d558-f557-4ef6-923f-26b484b5c3f0"
  ["EXPLORIS_1"]="5a975002-8db4-4789-b832-c09ec4ad76af"
  ["EXPLORIS_2"]="af3299e6-2423-4122-8220-96719849d4f9"
  ["QEXACTIVEHF_1"]="05a8c997-e77f-4add-a55e-ec3c40cbc98b"
  ["QEXACTIVEHF_4"]="50505a0b-7fc9-471e-b8c1-61fb51ed9b3b"
  ["QEXACTIVE_1"]="f96990c5-5d2a-42ac-8b38-31d341be673d"
  ["QEXACTIVE_2"]="d408f3e5-1371-4767-a631-5b6774206c23"
  ["QEXACTIVEHFX_1"]="fef21e50-b532-4c0e-9669-852972e28366")

#######################################
# Example:
# md5;time;size;filepath
# f336ff5cf2638759bddf1e99018f2bb0;1548307809;77991976;p3000/Proteomics/QEXACTIVEHFX_1/lkunz_20190123_HeLa_phospho_div_tests/20190123_11_autoQC01.raw
# 0aa572aa91be0cca43f41515b2903231;1548340209;73099850;p3000/Proteomics/QEXACTIVEHFX_1/lkunz_20190123_HeLa_phospho_div_tests/20190123_18_autoQC01.raw
#######################################
INPUT="/srv/www/htdocs/Data2San/sync_LOGS/pfiles.txt"
[[ -f ${INPUT} ]] || { echo "not $INPUT file."; exit 1; }

#######################################
# Compose one lftp command for each not transfered raw file 
# Globals:
#   labsysid
# Arguments:
#  prefix filepath filename instrument qctype md5
#   None
# Returns:
#   stdout
#######################################
function compose_lftp_command () {
  grep "$(basename $2)\|$6" ~cpanse/.lftp/transfer_log* > /dev/null
  if [ $? -eq 0 ]
    then 
      echo "# file '$2' ALREADY COPIED"
    else
      echo "put $1$2 -o $3_${labsysid[$4]}_$5_$6.raw"
      echo "sleep 1"
  fi
}


function main () {
  #set -x
  local INSTRUMENTPATTERN=`echo ${!labsysid[@]} | tr " " "|"`
  # local QCPATTERN="(autoQC01).*\.raw$"
  local QCPATTERN="(autoQC4L|autoQC01).*\.raw$"
  local now=$(date  "+%s")

  #set +x

  awk -F';' -v now=$now '$2 > (now - 60 * 60 * 24){print}' $INPUT \
    | egrep "(${INSTRUMENTPATTERN}).*${QCPATTERN}" \
    | while read i;
    do 
      filepath=$(echo $i | cut -d';' -f4)
      filename=$(basename $filepath .raw)
      instrument=$(echo $filepath | cut -d'/' -f3)
      qctype=$(echo $filename | sed 's/.*auto\(QC..\).*/\1/' | sed 's/QC4L/QC03/g')
      md5=$(echo $i | cut -d';' -f1)
    
      #sleep 1
      compose_lftp_command '/srv/www/htdocs/' $filepath $filename $instrument $qctype $md5
    done
}

main

exit $?
