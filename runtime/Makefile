CPP      := g++

SRC      := src
TARGET   := build

INCLUDES := -I$(SDK_DIR)/userspace/include \
            -I$(FLETCHER_RUNTIME_DIR)/fletcher/include
LIBS     := -larrow -lfpga_mgmt -lgomp

CPPFLAGS := -std=c++1y -Wall -O3 -fPIC -fopenmp

DEFINES  :=  

OBJECTS  := $(TARGET)/UserCore.o $(TARGET)/FPGAPlatform.o $(TARGET)/aws.o

all: pre-build FPGAPlatform.o UserCore.o aws.o
	$(CPP) -shared $(CPPFLAGS) $(OBJECTS) -o libfletcher.so $(LIBS) $(INCLUDES) $(DEFINES)

pre-build:
	mkdir -p $(TARGET) 

UserCore.o:
	$(CPP) -c $(CPPFLAGS) $(SRC)/fletcher/UserCore.cpp -o $(TARGET)/UserCore.o $(LIBS) $(INCLUDES) $(DEFINES)

FPGAPlatform.o:
	$(CPP) -c $(CPPFLAGS) $(SRC)/fletcher/FPGAPlatform.cpp -o $(TARGET)/FPGAPlatform.o $(LIBS) $(INCLUDES) $(DEFINES)

aws.o:
	$(CPP) -c $(CPPFLAGS) $(SRC)/fletcher/aws/aws.cpp -o $(TARGET)/aws.o $(LIBS) $(INCLUDES) $(DEFINES)

clean: 
	rm -f $(OBJECTS) 
	rm -f libfletcher.so
	rm -rf $(TARGET)

