# FGCZ transfer script 

copies all autoQC instrument files from http://fgcz-ms.uzh.ch to ftp://proteomics@perelman.crg.es/fgcz
using `lftp` and `cron`

## Requirements

-  linux, lftp, cron
-  ftp auth are kept in ~/.netrc 


## Platforms and versions the software has been deployed

|platform|platform version|bash version|note|
| :------- |:--------------|:------|:------- |
|Linux| 3.16.43-2+deb8u2 |  4.3.30(1)-release | [FGCZ fileserver](http://fgcz-ms.uzh.ch)|


## Input

`SOURCE="/srv/www/htdocs/Data2San/"`

```
p1000/Proteomics/QEXACTIVE_2/tobiasko_20180913/20180815_01_autoQC01.raw
p1000/Proteomics/QEXACTIVEHF_2/lkunz_20180907_test/20180907_001_autoQC01.raw
p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_001_autoQC01.raw
p1531/Proteomics/QEXACTIVEHF_1/selevsek_20180911/20180911_22_autoQC01.raw
p2883/Proteomics/QEXACTIVEHFX_1/lkunz_20180913_OID4796_DIA/20180913_001_autoQC01.raw
p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_002_autoQC01.raw
p2883/Proteomics/QEXACTIVEHFX_1/lkunz_20180913_OID4796_DIA/20180913_002_autoQC01.raw
p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_003_autoQC01.raw
p1000/Proteomics/FUSION_1/roschi_20180809_autoQC/20180912_07_autoQC01.raw
p2748/Proteomics/FUSION_2/lkunz_20180911_OID4763/20180911_025_autoQC01.raw
```

## Output  (`tail transfer_log`)

```
2018-09-13 10:59:06 /srv/www/htdocs/Data2San/p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_001_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/QEXACTIVEHF_2/1809/QC01/20180913_001_autoQC01.raw 0-63329767 38.20 MiB/s
2018-09-13 10:59:08 /srv/www/htdocs/Data2San/p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_002_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/QEXACTIVEHF_2/1809/QC01/20180913_002_autoQC01.raw 0-64371567 44.00 MiB/s
2018-09-13 10:59:10 /srv/www/htdocs/Data2San/p1531/Proteomics/QEXACTIVEHF_1/selevsek_20180911/20180911_22_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/QEXACTIVEHF_1/1809/QC01/20180911_22_autoQC01.raw 0-67686169 43.87 MiB/s
2018-09-13 10:59:12 /srv/www/htdocs/Data2San/p2706/Proteomics/QEXACTIVE_2/chiawei_20180308/20180308_06_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/QEXACTIVE_2/1809/QC01/20180308_06_autoQC01.raw 0-57255260 29.55 MiB/s
2018-09-13 10:59:14 /srv/www/htdocs/Data2San/p2883/Proteomics/QEXACTIVEHFX_1/lkunz_20180913_OID4796_DIA/20180913_001_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/QEXACTIVEHFX_1/1809/QC01/20180913_001_autoQC01.raw 0-73369846 45.80 MiB/s
2018-09-13 10:59:16 /srv/www/htdocs/Data2San/p2883/Proteomics/QEXACTIVEHFX_1/lkunz_20180913_OID4796_DIA/20180913_002_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/QEXACTIVEHFX_1/1809/QC01/20180913_002_autoQC01.raw 0-73270606 47.49 MiB/s
2018-09-13 11:59:05 /srv/www/htdocs/Data2San/p1000/Proteomics/FUSION_1/roschi_20180809_autoQC/20180912_07_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/FUSION_1/1809/QC01/20180912_07_autoQC01.raw 0-47766828 32.39 MiB/s
2018-09-13 11:59:07 /srv/www/htdocs/Data2San/p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_003_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/QEXACTIVEHF_2/1809/QC01/20180913_003_autoQC01.raw 0-63694477 42.94 MiB/s
2018-09-13 11:59:10 /srv/www/htdocs/Data2San/p2748/Proteomics/FUSION_2/lkunz_20180911_OID4763/20180911_025_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/FUSION_2/1809/QC01/20180911_025_autoQC01.raw 0-107287772 50.60 MiB/s
2018-09-13 12:59:05 /srv/www/htdocs/Data2San/p1000/Proteomics/QEXACTIVEHF_2/tobiasko_20180913/20180913_005_autoQC01.raw -> ftp://proteomics@perelman.crg.es/fgcz/QEXACTIVEHF_2/1809/QC01/20180913_005_autoQC01.raw 0-63243099 38.93 MiB/s
```

## Some statistics

```{bash}
#!/bin/bash
  
cat transfer_log* \
  | grep perelman.crg.es \
  | grep  "MiB/s$" \
  | sort \
  | awk '{print $1" "$(NF-1)" "$NF}' \
  > transfer.txt \
  && R --no-save <<EOF
op <- par(mfrow = c(2,1))
boxplot(S[,'V2'] ~ substr(S[,'V1'], 1, 7),
  log='y',
  main='FGCZ lftp/transfer_log to ftp://proteomics@perelman.crg.es/',
  ylab='throughput [MiB/s]',
  xlab='time YYYY-MM')

plot(table(substr(S[,'V1'],1,7)),
  type='b',
  ylab='number of transfered files',
  xlab='time YYYY-MM')
  
table(X<- data.frame(month=substr(S[,'V1'],1,7),QC=S$V4))

EOF
```
<img width="1665" alt="screen shot 2018-09-13 at 13 09 42" src="https://user-images.githubusercontent.com/4901987/45484991-51aa8400-b756-11e8-88b7-68230f6590cc.png">

<img width="1662" alt="screen shot 2018-09-13 at 13 42 49" src="https://user-images.githubusercontent.com/4901987/45486604-05624280-b75c-11e8-96a2-125100635c5f.png">

