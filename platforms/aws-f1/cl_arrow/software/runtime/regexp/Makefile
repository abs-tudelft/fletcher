CPP     := g++ 

PROGRAM := regexp

SRC     := 
TARGET  := build
 
INCLUDES:= -I$(SDK_DIR)/userspace/include -I$(FLETCHER_RUNTIME_DIR)/include

LIBS    := -lre2 -larrow -lfletcher -lfpga_mgmt -lgomp
LIBPATHS:= -L$(FLETCHER_RUNTIME_DIR)
 
CFLAGS  := -std=c++1y -O3 -Wall -fopenmp

DEFINES := 

OBJECTS := $(TARGET)/RegExUserCore.o
 
all: pre-build RegExUserCore.o
	$(CPP) $(CFLAGS) $(PROGRAM).cpp $(OBJECTS) -o $(PROGRAM) $(LIBPATHS) $(LIBS) $(INCLUDES) $(DEFINES)

pre-build:
	mkdir -p $(TARGET) 
	
RegExUserCore.o:
	$(CPP) -c $(CFLAGS) RegExUserCore.cpp -o $(TARGET)/RegExUserCore.o $(LIBS) $(INCLUDES) $(DEFINES)
   
clean: 
	rm -f $(OBJECTS) 
	rm -f $(PROGRAM)
	rm -rf $(TARGET)
