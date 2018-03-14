# Questasim utils

proc hline {} {
  echo "--------------------------------------------------------------------------------"
}

proc colorize {l c} {
  foreach obj $l {
    # get leaf name
    set nam [lindex [split $obj /] end]
    # change color
    property wave $nam -color $c
  }
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

proc add_waves {groups {in_color green} {out_color yellow} {internal_color white}} {
  for {set group_idx 0} {$group_idx < [llength $groups]} {incr group_idx} {
    set group [lindex [lindex $groups $group_idx] 0]
    set unit  [lindex [lindex $groups $group_idx] 1]
    add_colored_unit_signals_to_group $group $unit $in_color $out_color $internal_color
    WaveCollapseAll 0
  }
}

proc simulate {top groups_and_units} {
  vsim -novopt -assertdebug $top

  config    wave -signalnamewidth 1
  add_waves $groups_and_units green yellow white

  configure wave -namecolwidth    256
  configure wave -valuecolwidth   192

  run -all

  wave zoom full
}

