source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc simtest {{unit_name "*"} {tc_name "*"}} {

  if {$tc_name ne "*"} {
    set tc_name ${unit_name}_${tc_name}
  }

  set testcases [glob $::env(FLETCHER_HARDWARE_DIR)/streams/test/${unit_name}/${tc_name}_tc.vhd]
  set failures []
  set runs 0
  foreach testcase $testcases {

    set tc_name [file rootname [file tail $testcase]]
    set tc_name [string range $tc_name 0 [expr [string length $tc_name] - 4]]

    set unit_name [file tail [file dirname $testcase]]

    set lcname [string tolower ${tc_name}]
    set tbname sim:/${lcname}_tc/tb/*
    set uutname sim:/${lcname}_tc/tb/uut/*
    set tbsig [list "TB" $tbname]
    set uutsig [list "UUT" $uutname]
    set siglist [list $tbsig $uutsig]

    # Add UUT and testbench to sources to compile.
    foreach testbench [glob -nocomplain "$::env(FLETCHER_HARDWARE_DIR)/streams/test/${unit_name}/*_tb.vhd"] {
      add_source $testbench
    }
    foreach test_vector [glob -nocomplain "$::env(FLETCHER_HARDWARE_DIR)/streams/test/${unit_name}/*_tv.vhd"] {
      add_source $test_vector
    }
    add_source $::env(FLETCHER_HARDWARE_DIR)/streams/test/${unit_name}/${tc_name}_tc.vhd

    compile_sources

    if {[llength $testcases] > 1} {
      vsim -novopt -assertdebug work.${tc_name}_tc
      run 10 ms
    } else {
      simulate work.${tc_name}_tc $siglist
    }
    if {[runStatus] ne "ready"} {
      lappend failures $tc_name
    }
    incr runs

  }

  if {[llength $failures] > 0} {
    echo [expr $runs - [llength $failures]] "/" $runs "tests passed"
    echo "Failures:" $failures
    if [batch_mode] {
      echo "Running in batch mode, exiting with code 1"
      exit -code 1
    }
  } else {
    if {$runs eq 1} {
      echo "Requested test passed"
    } else {
      echo "All" $runs "requested tests passed"
    }
    if [batch_mode] {
      echo "Running in batch mode, exiting with code 0"
      exit -code 0
    }
  }

}

add_fletcher
add_fletcher_tb

if [batch_mode] {
  simtest
} else {
  echo "Use simtest \[unit name\] \[test case\] to simulate any stream component with a testbench."
  echo "Leave test case empty to run all tests for a unit, or don't specify any parameters to"
  echo "test everything."
  echo "Example: simtest StreamSlice"
}
