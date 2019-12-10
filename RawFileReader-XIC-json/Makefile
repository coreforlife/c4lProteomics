CSC=mcs
CSCFLAGS=-lib:./ /r:ThermoFisher.CommonCore.Data.dll /r:ThermoFisher.CommonCore.MassPrecisionEstimator.dll /r:ThermoFisher.CommonCore.RawFileReader.dll /optimize /platform:anycpu

test: run
	python json_test.py 
	
run: cmp
	bash runme.bash 

cmp:
	$(CSC) fgcz-xic.cs  /out:./fgcz-xic.exe  $(CSCFLAGS)
