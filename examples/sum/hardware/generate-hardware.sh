#!/usr/bin/env bash

# First run the Python script to generate a RecordBatch file (with schema inside)
python generate-input.py

# Run Fletchgen on the recordbatch
fletchgen -n Sum \
          -r recordbatch.rb \
          -s recordbatch.srec \
          -l vhdl \
          --sim