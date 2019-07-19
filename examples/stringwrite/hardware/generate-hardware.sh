#!/usr/bin/env bash

# First run the Python script to generate an Arrow Schema
python generate-schema.py

# Run Fletchgen on the recordbatch
fletchgen -i stringwrite.as \
	  -s recordbatch.srec \
          -l vhdl \
          --sim \
          --axi