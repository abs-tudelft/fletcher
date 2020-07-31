.PHONY: clean sim

all:
	python3 generate.py
	fletchgen -r src.rb -i dst.as -s memory.srec -l vhdl --sim

sim:
	rm -f vhdl/Kernel.gen.vhd
	vhdeps --no-tempdir -i ${FLETCHER_DIR}/hardware -i . ghdl SimTop_tc

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
	rm -f *.log
	rm -f *.cf
