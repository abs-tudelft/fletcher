.PHONY: sim clean

all:
	python generate-schema.py
	fletchgen -i stringwrite.as -t memory.srec -l vhdl dot --sim --regs c:32:strlen_min c:32:strlen_mask

sim:
	vhdeps -i ${FLETCHER_DIR}/hardware -i . ghdl SimTop_tc

clean:
	rm -rf dot
	rm -rf vhdmmio-doc
	rm -f fletchgen.mmio.yaml
	rm -f memory.srec
	rm -f vhdl/memory.srec
	rm -f vhdl/*.vhdt
	rm -f vhdl/StringWrite.vhd
	rm -f vhdl/mmio_pkg.gen.vhd
	rm -f vhdl/mmio.gen.vhd
	rm -f vhdl/vhdmmio_pkg.gen.vhd
	rm -f vhdl/Mantle.vhd
	rm -f vhdl/Nucleus_Kernel.vhd
