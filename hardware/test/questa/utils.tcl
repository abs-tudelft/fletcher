# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Various Questasim utilities

# get rid of the pesky spam
proc suppress_warnings {} {
  global StdArithNoWarnings
  global StdNumNoWarnings
  global NumericStdNoWarnings
  
  set StdArithNoWarnings 1
  set StdNumNoWarnings 1
  set NumericStdNoWarnings 1
  
  return
}

proc hline {} {
  echo "--------------------------------------------------------------------------------"
  return
}

proc colorize {l c} {
  foreach obj $l {
    # get leaf name
    set nam [lindex [split $obj /] end]
    # change color
    property wave $nam -color $c
  }
  return
}

proc add_colored_unit_signals_to_group {group unit in_color out_color internal_color} {
  # add wave -noupdate -expand -group $group -divider -height 32 $group
  add wave -noupdate -expand -group $group $unit

  set input_list    [lsort [find signals -in        $unit]]
  set output_list   [lsort [find signals -out       $unit]]
  set port_list     [lsort [find signals -ports     $unit]]
  set internal_list [lsort [find signals -internal  $unit]]

  # This could be used to work with dividers:
  colorize $input_list     $in_color
  colorize $output_list    $out_color
  colorize $internal_list  $internal_color
}

proc add_waves {groups {in_color #00FFFF} {out_color #FFFF00} {internal_color #FFFFFF}} {
  for {set group_idx 0} {$group_idx < [llength $groups]} {incr group_idx} {
    set group [lindex [lindex $groups $group_idx] 0]
    set unit  [lindex [lindex $groups $group_idx] 1]
    add_colored_unit_signals_to_group $group $unit $in_color $out_color $internal_color
    WaveCollapseAll 0
  }
}

proc simulate {top {groups_and_units 0} {duration -all}} {
  vsim -novopt -assertdebug $top
  
  suppress_warnings

  if [batch_mode] {
    echo "Running in batch mode. Skipping waveforms..."
  } else {
    if {$groups_and_units == 0} {
      echo "No groups and instances defined."
    } else {
      configure wave -signalnamewidth 1
      add_waves $groups_and_units
      configure wave -namecolwidth    256
      configure wave -valuecolwidth   192
    }
  }

  run $duration

  if [batch_mode] {
    quit
  } else {
    if {$groups_and_units == 0} {
      echo "Cannot zoom to full, no signals added."
    } else {
      wave zoom full
    }
  }
}
