vcom -2008 -work work axi.vhd
vcom -2008 -work work axi_mmio.vhd
vcom -2008 -work work axi_mmio_tb.vhd

vsim -novopt work.axi_mmio_tb

add wave sim:/axi_mmio_tb/*
add wave sim:/axi_mmio_tb/uut/*

run -all
