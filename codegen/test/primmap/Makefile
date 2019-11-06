.PHONY: clean sim

all:
	fletchgen -r twoprimread.rb -i twoprimwrite.as -s memory.srec -l dot vhdl --sim --regs c:8:add:0x01 s:32:sum

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
	rm -rf dot
	rm -f fletchgen.mmio.yaml
	rm -f memory.srec
	rm -f vhdl/*.gen.vhd
