#!/bin/bash


MONO=mono
RAWFILE=20190124_03_autoQC4L.raw
TOLPPM=10
MASSFILE=mp2h2p-LASVSVSR.txt 
OUTPUT=output.json

${MONO} fgcz-xic.exe ${RAWFILE} info

if [ $? -eq 0 ];
then
	echo "extracting XICs ... into file ${OUTPUT}"
	${MONO} fgcz-xic.exe ${RAWFILE} xic ${MASSFILE} ${TOLPPM} ${OUTPUT}
else
	exit 1
fi


