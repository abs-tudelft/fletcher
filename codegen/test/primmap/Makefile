all:
	fletchgen -r primread.rb -i primwrite.as -s memory.srec -l dot vhdl --sim --regs c:8:add s:32:sum

clean:
	rm -rf vhdmmio-doc
	rm -f fletchgen.mmio.yaml
	rm -f memory.srec
	rm -rf dot
	rm -f vhdl/*.vhdt
	rm -f vhdl/PrimWrite.vhd
	rm -f vhdl/PrimRead.vhd
	rm -f vhdl/mmio_pkg.gen.vhd
	rm -f vhdl/mmio.gen.vhd
	rm -f vhdl/vhdmmio_pkg.gen.vhd
	rm -f vhdl/Mantle.vhd
	rm -f vhdl/Nucleus_Kernel.vhd
