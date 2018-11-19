#!/bin/bash

if [[ $# -eq 2 ]]
then
	echo "This script cleans the given aws build directories."
	echo "Usage: $0 directory [directories ...]"
	echo "Example: clean.sh regexp"
fi

for project_dir in "$@"
do
	rm -r "$project_dir/verif/sim/"*
	rm "$project_dir/vivado"*.jou
	rm "$project_dir/vivado"*.log
	rm "$project_dir/build/src_post_encryption/"*
	rm "$project_dir/build/checkpoints/"*.dcp
	rm "$project_dir/build/checkpoints/to_aws/"*.dcp
	rm "$project_dir/build/scripts/"*.log
	rm "$project_dir/build/scripts/"*.out
	rm "$project_dir/build/scripts/fsm_encoding.os"
	rm "$project_dir/build/scripts/hd_visual/"*.tcl
	rm "$project_dir/build/reports/"*.rpt
	rm "$project_dir/design/ip/axi_interconnect_top/hdl/"*
	rm "$project_dir/design/ip/axi_interconnect_top/"*.dcp
	rm "$project_dir/design/ip/axi_interconnect_top/axi_interconnect_top_"*
	rm "$project_dir/design/ip/axi_interconnect_top/axi_interconnect_top."{veo,vho,xml}
  rm -r "$project_dir/design/ip/axi_interconnect_top/"{doc,hdl,sim,simulation,synth}
done
