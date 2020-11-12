.PHONY: clean sim

KERNEL = PrimMap

all:
	python3 generate-input.py
	fletchgen -n ${KERNEL} -r in.rb -i out.as -s batch.srec -l vhdl --sim --axi -e ext.yaml

sim:
	rm -f vhdl/${KERNEL}.gen.vhd
	rm -f vhdl/SimTop_tc.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . ghdl SimTop_tc

gui:
	rm -f vhdl/${KERNEL}.gen.vhd
	rm -f vhdl/SimTop_tc.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . --gui ghdl SimTop_tc

vsim:
	rm -f vhdl/${KERNEL}.gen.vhd
	rm -f vhdl/SimTop_tc.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . vsim SimTop_tc
	
vsim-gui:
	rm -f vhdl/${KERNEL}.gen.vhd
	rm -f vhdl/SimTop_tc.gen.vhd
	vhdeps -i ${FLETCHER_DIR}/hardware -i . --gui vsim SimTop_tc

clean:
	rm -rf vhdmmio-doc
	rm -rf dot
	rm -f fletchgen.mmio.yaml
	rm -f batch.srec
	rm -f vhdl/*.gen.vhd
