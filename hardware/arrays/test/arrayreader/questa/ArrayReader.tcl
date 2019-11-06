source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

# Simulate random ArrayReaders

# generate a new ArrayReader
proc gen_cr {{seed -1}} {
  exec rm -f ArrayReader_tb.vhd

  if {$seed == -1} {
    exec python3 ../gen_tb.py > ArrayReader_tb.vhd
  } else {
    echo "Seed = $seed"
    exec python3 ../gen_tb.py $seed > ArrayReader_tb.vhd
  }
  
  add_source ArrayReader_tb.vhd
  
  echo "New ArrayReader testbench generated."
}

# Simulate in GUI:
proc sim_cr {} {
  compile_sources
  simulate ArrayReader_tb {{"TestBench" sim:/arrayreader_tb/*}}
}

proc batch_sim_cr {} {
  set ok 0
  set config_string "<unknown, compile error>"
  onbreak {resume}
  if {[catch {
    # compile arrayreader tb the old fashioned way to increase batch sim throughput
    # spam suppression of numeric std warnings. Who knows where to actually insert it?
    suppress_warnings
    vcom -quiet -work work -93 ArrayReader_tb.vhd
    suppress_warnings
    vsim -quiet -suppress 8684,3813 -novopt work.arrayreader_tb
    suppress_warnings
    run -all
    set ok [examine sim_complete]
    set config_string [examine arrayreader_tb/uut/CFG]
  }]} {
    set ok 0
  }
  hline
  echo "Simulation ArrayReader with config string $config_string ended."

  if {$ok == 1} {
    echo "Succes."
    return 1
  } else {
    echo "Failure."
    set chksum [lindex [regexp -all -inline {\S+} [exec sha1sum ArrayReader_tb.vhd]] 0]
    echo "Test bench file saved in failures/$chksum\.vhd"
    exec mkdir -p failures
    exec cp ArrayReader_tb.vhd failures/$chksum\.vhd
    return 0
  }
}

proc batch_sim {{count 10} {max_fail 1}} {
  echo "Starting ArrayReader test loop"

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

add_fletcher
add_fletcher_tb
compile_sources

if {[batch_mode] == 1} {
  batch_sim 10000 1
  quit
} else {
  echo "Commands:"
  echo " - gen_cr: generates a new random ArrayReader."
  echo " - sim_cr: compiles and simulates the current ArrayReader."
  echo " - batch_sim count=10 max_fail=1: batch-simulates a number of random ArrayReaders."
}
