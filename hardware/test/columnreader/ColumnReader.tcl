source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

# Simulate random ColumnReaders

# generate a new ColumnReader
proc gen_cr {{seed -1}} {
  exec rm -f ColumnReader_tb.vhd

  if {$seed == -1} {
    exec python3 gen_tb.py > ColumnReader_tb.vhd
  } else {
    echo "Seed = $seed"
    exec python3 gen_tb.py $seed > ColumnReader_tb.vhd
  }
  
  add_source ColumnReader_tb.vhd
  
  echo "New ColumnReader testbench generated."
}

# Simulate in GUI:
proc sim_cr {} {
  compile_sources
  simulate ColumnReader_tb {{"TestBench" sim:/columnreader_tb/*}}
}

proc batch_sim_cr {} {
  set ok 0
  set config_string "<unknown, compile error>"
  onbreak {resume}
  if {[catch {
    # compile columnreader tb the old fashioned way to increase batch sim throughput
    # spam suppression of numeric std warnings. Who knows where to actually insert it?
    suppress_warnings
    vcom -quiet -work work -93 ColumnReader_tb.vhd
    suppress_warnings
    vsim -quiet -suppress 8684,3813 -novopt work.columnreader_tb
    suppress_warnings
    run -all
    set ok [examine sim_complete]
    set config_string [examine columnreader_tb/uut/CFG]
  }]} {
    set ok 0
  }
  hline
  echo "Simulation ColumnReader with config string $config_string ended."

  if {$ok == 1} {
    echo "Succes."
    return 1
  } else {
    echo "Failure."
    set chksum [lindex [regexp -all -inline {\S+} [exec sha1sum ColumnReader_tb.vhd]] 0]
    echo "Test bench file saved in failures/$chksum\.vhd"
    exec mkdir -p failures
    exec cp ColumnReader_tb.vhd failures/$chksum\.vhd
    return 0
  }
}

proc batch_sim {{count 10} {max_fail 1}} {
  echo "Starting ColumnReader test loop"

  set failures 0
  for {set i 1} {$i <= $count} {incr i} {
    hline
    # generate a new cr
    gen_cr
    
    # simulate it and check result
    if {[batch_sim_cr] == 0} {
      incr failures
    }
    if {$failures >= $max_fail} {
      echo "Stopping because failure limit has been reached"
      break
    }
    echo "Run $i/$count. Failures: $failures/$max_fail"
  }
  if {$failures > 0} {
    echo "Failures:" $failures"."
  } else {
    echo "All runs were successful!"
  }
  return $failures == 0
}

# Add the codegen directory to Python's module search path
set py_module_path [file join [pwd] $::env(FLETCHER_CODEGEN_DIR)]

echo "Python module path: " $py_module_path

if { [info exists ::env(PYTHONPATH)] } {
  set ::env(PYTHONPATH) $py_module_path:$::env(PYTHONPATH)
} else {
  set ::env(PYTHONPATH) $py_module_path
}

add_fletcher
add_fletcher_tb
compile_sources

if {[batch_mode] == 1} {
  batch_sim 10000 1
  quit
} else {
  echo "Commands:"
  echo " - gen_cr: generates a new random ColumnReader."
  echo " - sim_cr: compiles and simulates the current ColumnReader."
  echo " - batch_sim count=10 max_fail=1: batch-simulates a number of random ColumnReaders."
}
