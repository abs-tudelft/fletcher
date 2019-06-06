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

###############################################################################
# QuestaSim compilation script.
 
# Usage:
#   do compile.tcl
#   add_source some_source.vhd -93
#   add_source another_source.vhd -2008
#   compile_sources
# 
# After making changes to any file; only run compile_sources. Only changed 
# files are now compiled.

# Loosely inspired by the script here: 
# https://www.doulos.com/knowhow/tcltk/examples/modelsim/
# but adds a md5 hash check next to timestamp to make sure files are really
# different. This is useful when files update very fast due to the use of HDL
# generators. Also, doesn't do other libraries than "work".

###############################################################################

# Procedures:

# get the current timestamp
proc timestamp {} {
  return [clock seconds]
}

proc check_new_compile_dir {} {
  global compile_dir
  # Check if we changed directory. If so, we need to make a new list
  if {[pwd] != $compile_dir} {
    set compile_dir [pwd]
    echo "Working directory changed."
    clear_compile_list
  }
}

# clear the compilation list and the work library
proc clear_compile_list {} {
  global compile_list
  global compile_dir
  
  # Delete what was already in "work". It's optional, but recommended if 
  # changes to the compile script are still being made.
  catch {vdel -all -lib work}
  vlib work
  
  echo "Clearing compilation list."
  
  set compile_list [list]
  set compile_dir [pwd]
}

# Add a file to the compilation list
proc add_source {file_name {file_mode -93}} {
  global compile_list
  
  check_new_compile_dir
  
  if {[file exists $file_name]} {
    # calculate md5 hash
    set file_hash [md5::md5 -hex $file_name]
      
    # Check if file exists in list
    for {set i 0} {$i < [llength $compile_list]} {incr i} {
      set comp_unit [lindex $compile_list $i]
      if {[lindex $comp_unit 0] == $file_name} {
        # file exists, check if mode changed
        if {[lindex $comp_unit 3] != $file_mode} {
          # change the mode and reset the timestamp
          lset compile_list $i [list $file_name $file_hash 0 $file_mode]
        }
        return
      }
    }
  
    # if the file isn't in the list yet, so we haven't returned, add file to 
    # compile list
    lappend compile_list [list $file_name $file_hash 0 $file_mode]
  } else {
    error $file_name " does not exist."
  }
  return
}

# Add all files to the compilation list
proc add_directory {path_name {path_mode -93}} {
  # TODO: select proper version after sim framework refactor.
  global compile_list
  
  check_new_compile_dir
  
  if {[file isdirectory $path_name]} {
    set path_files [glob -directory $path_name *.{vhd,vhdl}]
    foreach f $path_files {
      add_source $f
    }
  }
}

# compile all sources added to the compilation list
proc compile_sources {{quiet 1}} {
  global compile_list
  
  check_new_compile_dir
  
  set up_to_date 0
  set new 0
  
  # loop over each compilation unit
  for {set i 0} {$i < [llength $compile_list]} {incr i} {
    set comp_unit [lindex $compile_list $i]
    
    # extract file information
    set file_name [lindex $comp_unit 0] 
    set file_hash [lindex $comp_unit 1]
    set file_last [lindex $comp_unit 2]
    set file_mode [lindex $comp_unit 3]
        
    # check if file still exists
    if {[file exists $file_name]} {
      
      # get file info from disk
      set file_disk_time [file mtime $file_name]
      set file_disk_hash [md5::md5 -hex $file_name]
      
      set file_name_split [split $file_name /]
      set file_short [lindex $file_name_split [expr [llength $file_name_split] - 1]]

      # check if file needs to be recompiled
      if {($file_disk_time > $file_last) || ($file_hash != $file_disk_hash)} {
        echo "Compiling \($file_mode\):" $file_short
                
        # compile the file
        vcom -quiet -work work $file_mode $file_name
        
        # if compilation failed, the script will exit and the file will not be
        # added to the compile list.
        
        # update the compile list
        lset compile_list $i [list $file_name $file_hash [timestamp] $file_mode]
        
        incr new
      } else {
        incr up_to_date
        if {!$quiet} {
          echo "Up-to-date:" $file_short
        }
      }
    } else {
      echo "File " $file_name " no longer exists. Removing from compile list."
      set compile_list [lreplace $compile_list $i $i]
    }
  }
  echo "Compiled" $new "sources, skipped" $up_to_date "up-to-date sources."
}

# recompile all sources added to the compilation list
proc recompile_sources {{quiet 1}} {
  global compile_list
  
  # loop over each compilation unit
  for {set i 0} {$i < [llength $compile_list]} {incr i} {
    set comp_unit [lindex $compile_list $i]
    
    # extract file information
    set file_name [lindex $comp_unit 0] 
    set file_hash [lindex $comp_unit 1]
    set file_mode [lindex $comp_unit 3]

    # set timestamp to 0
    lset compile_list $i [list $file_name $file_hash 0 $file_mode]
  }
  compile_sources $quiet
}

# Initialization :

# Load and initialize stuff only when not done already
if {[info exists fletcher_compile_script_loaded] == 0} {
  set fletcher_compile_script_loaded 1
  
  echo "Fletcher compilation utilities."

  # Script initialization:

  echo "- Loading MD5 package..."
  package require md5

  set compile_list [list]
  clear_compile_list
  set compile_dir [pwd]
} else {
  echo "Fletcher compilation utilities already loaded. "
  echo "Use clear_compile_list to clear any existing compilations."
  check_new_compile_dir
}
