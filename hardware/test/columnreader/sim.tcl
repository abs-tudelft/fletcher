# Simulate a hundred random ColumnReaders

do ../compile.tcl
do ../utils.tcl

# Add the codegen directory to Python's module search path
set py_module_path [file join [pwd] $::env(FLETCHER_CODEGEN_DIR)]

echo "Python module path: " $py_module_path

if { [info exists ::env(PYTHONPATH)] } {
  set ::env(PYTHONPATH) $py_module_path:$::env(PYTHONPATH)
} else {
  set ::env(PYTHONPATH) $py_module_path
}

proc recompile {} {
  compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl
}

proc gen_cr {{seed -1}} {
  hline
  echo "Generating new ColumnReader"
  hline
  
  exec rm -f ColumnReader_tb.vhd
  
  if {$seed == -1} {
    exec python3 gen_tb.py > ColumnReader_tb.vhd
  } else {
    echo "Seed = $seed"
    exec python3 gen_tb.py $seed > ColumnReader_tb.vhd
  }

}

proc sim_cr {} {
  
  vcom -quiet -work work -93 ColumnReader_tb.vhd
  
  # GUI Simulation:
  simulate ColumnReader_tb {{"TestBench" sim:/columnreader_tb/*}}
  
}

proc batch_sim_cr {} {

  set ok 0
  set config_string "<unknown, compile error>"
  onbreak {resume}
  if {[catch {
    vcom -quiet -work work -93 ColumnReader_tb.vhd
    vsim -quiet -novopt work.columnreader_tb  
    run -all
    set ok [examine sim_complete]
    set config_string [examine columnreader_tb/uut/CFG]
  }]} {
    set ok 0
  }

  hline
  echo "Simulation end of ColumnReader with config string $config_string"
  hline

  if {$ok == 1} {
    echo "Simulation succes!"
    return 1
  } else {
    echo "Simulation failure!"
    hline
    set chksum [lindex [regexp -all -inline {\S+} [exec sha1sum ColumnReader_tb.vhd]] 0]
    
    echo "Test bench file saved in failures/$chksum\.vhd"
    
    exec mkdir -p failures
    
    exec cp ColumnReader_tb.vhd failures/$chksum\.vhd
    hline
    return 0
  }
  
}

proc batch_sim {{count 10} {max_fail 1}} {
  hline
  echo "Starting ColumnReader test loop"
  hline

  set failures 0
  for {set i 1} {$i <= $count} {incr i} {
    gen_cr
    if {[batch_sim_cr] == 0} {
      incr failures
    }
    if {$failures >= $max_fail} {
      echo "Stopping because failure limit has been reached"
      break
    }
    echo "That was run $i/$count, currently $failures/$max_fail failed"
  }
  hline
  if {$failures > 0} {
    echo "There were $failures failures!"
  } else {
    echo "All runs were successful!"
  }
  hline
  return $failures == 0
}


set NumericStdNoWarnings 1
set StdArithNoWarnings 1

recompile

if {[batch_mode] == 1} {
  batch_sim 10000 1
  quit
} else {
  echo "Commands:"
  echo " - recompile: recompiles the fletcher libraries."
  echo " - gen_cr: generates a new random ColumnReader."
  echo " - sim_cr: compiles and simulates the current ColumnReader."
  echo " - batch_sim count=10 max_fail=1: batch-simulates a number of random ColumnReaders."
}
