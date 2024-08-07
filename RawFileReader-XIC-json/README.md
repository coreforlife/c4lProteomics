# extract XIC from ThermoFisher raw files 

this folder contains a running C# code snippet 


## 1. System Requirements

a Windows/Linux/MacOSX x64 platform


### 1.1 .NET Framework and R

- https://www.mono-project.com/ (>4.0.22) for (Linux and MacOSX)
- .NET Framework 4.5.1 or higher (Windows)
- The [New RawFileReader from Thermo Fisher Scientific](http://planetorbitrap.com/rawfilereader)
dlls should be in the folder containing the [mono exe file](https://github.com/coreforlife/c4lProteomics/releases/tag/xic)


## required files

your directory should look like that
```
$  (master)> ls -l
total 427424
-r--r--r--  1 cp  staff  217738234 Oct  8 15:02 20190124_03_autoQC4L.raw
-rwxr-xr-x  1 cp  staff        309 Oct  8 15:02 Makefile
-rw-r--r--  1 cp  staff       5590 Oct  8 15:12 README.md
-rw-r--r--  1 cp  staff      43520 Oct  8 15:02 ThermoFisher.CommonCore.BackgroundSubtraction.dll
-rw-r--r--  1 cp  staff     360448 Oct  8 15:02 ThermoFisher.CommonCore.Data.dll
-rw-r--r--  1 cp  staff      11264 Oct  8 15:02 ThermoFisher.CommonCore.MassPrecisionEstimator.dll
-rw-r--r--  1 cp  staff     620544 Oct  8 15:02 ThermoFisher.CommonCore.RawFileReader.dll
-rw-r--r--  1 cp  staff      16238 Oct  8 15:02 fgcz-xic.cs
-rwxr-xr-x  1 cp  staff      13312 Oct  8 15:23 fgcz-xic.exe
-rw-r--r--  1 cp  staff        116 Oct  8 15:02 json_test.py
-rw-r--r--  1 cp  staff         18 Oct  8 15:02 masses.txt
-rw-r--r--  1 cp  staff       3915 Oct  8 15:24 output.json
-rwxr-xr-x  1 cp  staff        302 Oct  8 15:02 runme.bash
```

## commandline options

```{bash}
#!/bin/bash


MONO=mono
RAWFILE=20190124_03_autoQC4L.raw
TOLPPM=10
MASSFILE=masses.txt
OUTPUT=output.json

${MONO} fgcz-xic.exe ${RAWFILE} info

if [ $? -eq 0 ];
then
	echo "extracting XICs ... into file ${OUTPUT}"
	${MONO} fgcz-xic.exe ${RAWFILE} xic ${MASSFILE} ${TOLPPM} ${OUTPUT}
else
	exit 1
fi


```

## run

assuming there is a rawfile named `20190124_03_autoQC4L.raw`

```
mcs fgcz-xic.cs  /out:./fgcz-xic.exe  -lib:./ /r:ThermoFisher.CommonCore.Data.dll /r:ThermoFisher.CommonCore.MassPrecisionEstimator.dll /r:ThermoFisher.CommonCore.RawFileReader.dll /optimize /platform:anycpu
Compilation succeeded - 1 warning(s)
bash runme.bash 
Number of instruments: 2
General File Information:
    RAW file: 20190124_03_autoQC4L.raw
    RAW file version: 66
    Creation date: 1/24/2019 4:03:49 PM
    Operator: Administrator
    Number of instruments: 2
    Description: 
    Instrument model: Orbitrap Fusion Lumos
    Instrument name: Orbitrap Fusion Lumos
    Serial number: FSN20583
    Software version: 3.1.2412.25
    Firmware version: 
    Units: None
    Mass resolution: 0.500 
    Number of scans: 33972
    Number of ms2 scans: 29641
    Scan range: [1, 33972]
    Time range: [0.00, 75.00]
    Mass range: [91.0000, 2000.0000]

Sample Information:
    Sample name: 
    Sample id: 1:A,1
    Sample type: Unknown
    Sample comment: 
    Sample vial: 1:F,7
    Sample volume: 0
    Sample injection volume: 2
    Sample row number: 2
    Sample dilution factor: 1

Filter Information:
    Scan filter (first scan): FTMS + c ESI Full ms [350.0000-1500.0000]
    Scan filter (last scan): FTMS + c ESI Full ms [350.0000-1500.0000]
    Total number of filters: 11370

extracting XICs ... into file output.json
python json_test.py 
[{u'rt': [24.7442665669333, 24.7948425466333, 24.84745783385, 24.8951758178333, 24.9464644133167, 24.9995444989, 25.0281897541, 25.0784011530667, 25.1157983725333, 25.16302447305, 25.2157631685167, 25.263118036, 25.3146712175833, 25.3669742122333, 25.41612739945, 25.4669304013167, 25.5171357570667, 25.5665720805167, 25.6170378143833, 25.6573930973167, 25.7082003727833, 25.7604264285167, 25.8062942167833, 25.8577285653167, 25.9044608845167, 25.9535766293167, 26.0033631463833, 26.0531034623833, 26.10452553305, 26.1586075559667, 26.2111879149, 26.2566825717, 26.3619783293, 26.4141165112, 26.4662927053167, 26.5172478605333, 26.5650926805167, 26.6643468943833, 26.76346975225, 26.9652362746333, 27.2582697431833, 27.3074311352, 27.40991859385, 27.4597821293333, 27.8036144834667, 27.9936583663833, 28.935632176, 29.3744794256, 34.7499569151833, 34.8009871127833, 34.85139845625, 36.2440543021, 37.2166131258333, 37.2678554831667, 38.5827151909333, 40.0406153325167, 42.2495414109, 68.5624019703833, 69.67229028025, 69.9811920365167, 71.40055338345, 72.07607649385, 72.6971174184, 73.99858756265, 74.0048126807833, 74.21232263145, 74.2184164237333, 74.2244494530667, 74.2304764159833, 74.23656213705, 74.25355919865, 74.25964495625, 74.2765508319833, 74.2970353938667, 74.3171187229167, 74.32452070025, 74.34095736425, 74.3531199973167, 74.3691192839833, 74.4378844794667, 74.4440139341333, 74.4574466008, 74.52678256745, 74.59278167305], u'intensities': [212771.5625, 771243.25, 252197328, 605881920, 549134400, 366637952, 304315424, 201113440, 113934624, 49761184, 18782352, 11210953, 6987690.5, 5310394.5, 4423044, 3264363.75, 2657227.25, 1607360.75, 3054242, 1869842.625, 1925017, 1806214.375, 2420130.25, 1603274.375, 1218712.875, 863970.0625, 1218235.875, 3992280.25, 6483195.5, 3058246.25, 2334238.5, 688689.125, 234073.453125, 429985.53125, 416572.125, 311574.78125, 579365.4375, 508093.625, 214557.03125, 430939.875, 568169.125, 338341.9375, 299198.15625, 412163.28125, 293433.09375, 253470.921875, 300284.8125, 224634.75, 413924.65625, 451158.875, 607428.6875, 250979.953125, 558696.3125, 455832.875, 263813.75, 321462.125, 293740.6875, 144153.4375, 52125.05078125, 12845.2705078125, 9813.5283203125, 6216.9794921875, 3388.05639648438, 9747.8828125, 10518.8369140625, 363551.78125, 623123.25, 481624.28125, 1307023.875, 1886260.375, 632608.8125, 893255.875, 290351.25, 200927.375, 179677.625, 147042.390625, 106839.625, 125970.40625, 86633.1796875, 48804.671875, 48104.4140625, 48308.62109375, 37692.0546875, 14146.380859375], u'mass': 428.2738}, {u'rt': [5.76702193465, 24.84745783385, 24.8951758178333, 24.9464644133167, 24.9995444989, 25.0281897541, 25.0784011530667, 25.1157983725333, 25.16302447305, 25.2157631685167, 25.263118036, 25.3146712175833, 25.3669742122333, 25.4669304013167, 25.6573930973167, 25.8062942167833, 26.10452553305, 26.6643468943833, 28.0447280778333, 59.4204820191833, 69.8297224701167, 70.67890629865], u'intensities': [27069.873046875, 17593194, 58182836, 58966316, 44047492, 32866282, 25575700, 13597515, 6363145, 1927759, 364028.40625, 620153.4375, 520767.34375, 674679.75, 329264.3125, 282277.375, 329032.0625, 267380.625, 296655.84375, 206377.390625, 26431.876953125, 15971.896484375], u'mass': 424.2667}]
```


## cite

- The [New RawFileReader from Thermo Fisher Scientific](http://planetorbitrap.com/rawfilereader).
- [rawDiag, DOI: 10.1021/acs.jproteome.8b00173](https://pubs.acs.org/doi/10.1021/acs.jproteome.8b00173).
