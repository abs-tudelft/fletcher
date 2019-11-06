.PHONY: clean sim gui

all:
	fletchgen -r names.rb -s memory.srec -l vhdl dot --sim

sim:
	rm -f vhdl/Kernel.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . ghdl SimTop_tc

gui:
	rm -f vhdl/Kernel.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . --gui ghdl SimTop_tc

vsim:
	rm -f vhdl/Kernel.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . vsim SimTop_tc
	
vsim-gui:
	rm -f vhdl/Kernel.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . --gui vsim SimTop_tc

clean:
	rm -rf vhdmmio-doc
	rm -f fletchgen.mmio.yaml
	rm -f memory.srec
	rm -rf dot
	rm -f vhdl/*.gen.vhd
