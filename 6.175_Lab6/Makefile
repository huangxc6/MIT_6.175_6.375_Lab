CONNECTALDIR ?= /opt/connectal
S2H_INTERFACES = \
	ConnectalProcRequest:ConnectalWrapper.connectProc
H2S_INTERFACES = \
	ConnectalWrapper:ConnectalProcIndication
BSVFILES += \
	src/includes/Ifc.bsv
BSVPATH += / \
	src/ \
	src/includes \
	$(CONNECTALDIR)/bsv
CPPFILES += \
	main.cpp

#CONNECTALFLAGS += --mainclockperiod=20
#CONNECTALFLAGS += --verilog=ddr3_v2_0/
SOFTWARE_SOCKET_NAME=/tmp/connectal$(USER)
export SOFTWARE_SOCKET_NAME
CONNECTALFLAGS += -D $(VPROC)
CONNECTALFLAGS += --bscflags " -D $(VPROC) -steps-max-intervals 50 +RTS -K256M -RTS"
CONNECTALFLAGS += --bscflags " -show-schedule"
#CONNECTALFLAGS += --cxxflags="-g -std=gnu++11"

include $(CONNECTALDIR)/Makefile.connectal


clean:
	rm -rf bluesim logs buildDir

build:
	mkdir buildDir
	bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -p +:src/includes/ -aggressive-conditions -keep-fires src/SixStageBonus.bsv
	bsc -u -sim -bdir buildDir -info-dir buildDir -simdir buildDir -vdir buildDir -p +:src/includes:src/ref:src -D CORE_NUM=2 -D VPROC=SIXSTAGE -aggressive-conditions -keep-fires src/ConnectalWrapper.bsv

# docker exec -it --user root 69f1023564a4 /bin/bash

