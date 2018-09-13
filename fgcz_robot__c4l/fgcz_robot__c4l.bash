#!/bin/bash
# 
# Synchronises Mass Spectrometric (MS) Quality Control (QC) data to CRG.ES
#
# the code is trigged by using cron. A cron entry (crontan) on 
# our system look like that:
# */59 * * * *  /srv/FGCZ/fgcz/computer/fgcz-s-021/sync/fgcz_robot__c4l.bash 2>&1 >> ~/data/c4l_lftp.log
#
# Author: Christian Panse <cp@fgcz.ethz.ch>
#
# $HeadURL: https://fgcz-svn.uzh.ch/repos/fgcz/computer/fgcz-s-021/sync/fgcz_robot__c4l.bash $
# $Id: fgcz_robot__c4l.bash 8974 2018-08-14 09:33:19Z  $
# $Date: 2018-08-14 11:33:19 +0200 (Tue, 14 Aug 2018) $

#######################################
# Requirements:
#   linux, lftp, cron
#   ftp auth are keept in ~/.netrc 
#   expect files are kept in '/srv/www/htdocs/Data2San/' having the following file system hierarchy
# p1000/Proteomics/QEXACTIVE_2/tobiasko_20180913/20180815_01_autoQC01.raw
# p1000/Proteomics/QEXACTIVEHF_2/lkunz_20180907_test/20180907_001_autoQC01.raw
# p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_001_autoQC01.raw
# p1531/Proteomics/QEXACTIVEHF_1/selevsek_20180911/20180911_22_autoQC01.raw
# p2883/Proteomics/QEXACTIVEHFX_1/lkunz_20180913_OID4796_DIA/20180913_001_autoQC01.raw
# p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_002_autoQC01.raw
# p2883/Proteomics/QEXACTIVEHFX_1/lkunz_20180913_OID4796_DIA/20180913_002_autoQC01.raw
# p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_003_autoQC01.raw
# p1000/Proteomics/FUSION_1/roschi_20180809_autoQC/20180912_07_autoQC01.raw
# p2748/Proteomics/FUSION_2/lkunz_20180911_OID4763/20180911_025_autoQC01.raw

set -e
set -o pipefail

scriptname=$(basename $0)
lock="/tmp/${scriptname}"
exec 200>$lock
flock -n 200 || exit 1

SOURCE="/srv/www/htdocs/Data2San/"

#######################################
# This function generates a lftp command line
# Arguments:
#   file path
# Returns:
#   lftp command line string  on stdout, e.g,
#   mirror -R --no-recursion --include 20170119_01_QC01.raw /srv/www/htdocs/Data2San/p1755/Proteomics/QEXACTIVE_2/paolo_20160514_QC1_BSA /fgcz/QEXACTIVE_2/0514/QC01/
#######################################
function generate_lftp_cmd(){
  file=$1

  ff=`basename $file`
  dd=`dirname $file`
  
  dateYM=`ls --time-style='+%y%m' -lgo $file | awk '{print $4}'`

  # TODO(cp@fgcz.ethz.ch): new autoQC4L; change patter QC0[12] to autoQC0[12]
  ftpdir=`echo "$file D$dateYM" \
    | sed -n 's/.*Proteomics\/\([A-Z]*_[1-9]\)\/[a-z]*_20\([1-9][0-9][01][0-9]\)[0123][0-9].*\/\(.*\([qQ][cC]0[12]\|[qQ][cC]4[lL]\).*\.raw\).D\([0-9]*\)$/\/fgcz\/\1\/\5\/\4/p'`

  grep -l "$ff" ~/.lftp/transfer_log 1>/dev/null 2>/dev/null \
  || echo "mirror -R --no-recursion --include $ff $SOURCE/$dd/ $ftpdir" 
}


# MAIN
cd $SOURCE \
 && find . -iname "*.raw" -mmin -180 -type f \
  | egrep "\.\/p[0-9]+" \
  | egrep "[qQ][cC]0[12]|[qQ][cC]4[lL]" \
  | egrep "QEXACTIVEHF_1|QEXACTIVEHF_2|QEXACTIVE_1|QEXACTIVE_2|FUSION_1|FUSION_2|QEXACTIVEHFX_1" \
  | while read f;
  do
    generate_lftp_cmd $f \
      | awk '$NF~/fgcz\/[A-Z]+_[123]\/[0-9]{4}\/([qQ][cC]0[12]|[qQ][cC]4[lL])/{print}'
  done \
  > /tmp/c4l.lftp 

[ -s /tmp/c4l.lftp ] && lftp perelman.crg.es < /tmp/c4l.lftp 
[ -f /tmp/c4l.lftp ] && mv /tmp/c4l.lftp /tmp/c4l.lftp.old 

exit 0
