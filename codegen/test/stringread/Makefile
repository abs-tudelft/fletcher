.PHONY: clean sim gui

all:
	fletchgen -r names.rb -s memory.srec -l vhdl dot --sim

sim:
	vhdeps -i ${FLETCHER_DIR}/hardware -i . ghdl SimTop_tc

gui:
	vhdeps -i ${FLETCHER_DIR}/hardware -i . --gui ghdl SimTop_tc

clean:
	rm -rf vhdmmio-doc
	rm -f fletchgen.mmio.yaml
	rm -f memory.srec
	rm -rf dot
	rm -f vhdl/*.vhdt
	rm -f vhdl/mmio_pkg.gen.vhd
	rm -f vhdl/mmio.gen.vhd
	rm -f vhdl/vhdmmio_pkg.gen.vhd
	rm -f vhdl/StringRead.vhd
	rm -f vhdl/Nucleus_Kernel.vhd
	rm -f vhdl/Mantle.vhd
	rm -f vhdl/SimTop_tc.vhd
