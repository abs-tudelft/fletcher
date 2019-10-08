.PHONY: clean sim gui

all:
	python generate-input.py
	fletchgen -n Sum -r recordbatch.rb -s memory.srec -l vhdl --sim

sim:
	vhdeps -i ${FLETCHER_DIR}/hardware -i . ghdl SimTop_tc

gui:
	vhdeps -i ${FLETCHER_DIR}/hardware -i . --gui ghdl SimTop_tc

clean:
	# input files
	rm -f recordbatch.rb
	# vhdmmio stuff	
	rm -rf vhdmmio-doc
	rm -f fletchgen.mmio.yaml
	rm -f vhdl/mmio_pkg.gen.vhd
	rm -f vhdl/mmio.gen.vhd
	rm -f vhdl/vhdmmio_pkg.gen.vhd
	# fletchgen stuff
	rm -f memory.srec
	rm -rf dot
	rm -f vhdl/*.vhdt
	rm -f vhdl/ExampleBatch.vhd
	rm -f vhdl/Nucleus_Sum.vhd
	rm -f vhdl/Mantle.vhd
	rm -f vhdl/SimTop_tc.vhd
