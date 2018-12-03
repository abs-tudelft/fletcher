#!/usr/bin/python

from __future__ import print_function
import sys

def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)

# Generates verilog code to copy data into memory of AWS fpga instances (simulation only)

eprint("Waiting for SREC input on stdin")

line_nr = 0
for line in sys.stdin:
  line_nr = line_nr + 1

  if line[0] != "S":
    eprint("Input format error, expected 'S'")
    sys.exit(1)
  if   line[1] == "1":
    addr_length = 16
  elif line[1] == "2":
    addr_length = 24
  elif line[1] == "3":
    addr_length = 32
  else:
    eprint("Unsupported type: ", line[1])
    sys.exit(1)

  record_length = int(line[2:4], 16)
  expected_len = record_length*2 + 4
  checksum = int(line[expected_len-2:expected_len], 16)
  address = int(line[4:4+addr_length/4], 16)
  checksum_intermediate = 0
  for n in xrange(addr_length/4+4, expected_len-2, 2):
    byte_n = line[n:n+2]
    byte_val = int(byte_n, 16)
    checksum_intermediate = checksum_intermediate + byte_val
    print("tb.hm_put_byte(.addr(%d), .d(8'h%s));" % (address, byte_n))
    address = address + 1

  for n in xrange(2, addr_length/4+4, 2):
    byte_n = line[n:n+2]
    byte_val = int(byte_n, 16)
    checksum_intermediate = checksum_intermediate + byte_val
  checksum_calc = (checksum_intermediate % 256) ^ 0xFF
  if checksum != checksum_calc:
    eprint("Checksum mismatch on line %d (expected %X, calculated %X)" % (line_nr, checksum, checksum_calc))
    sys.exit(1)

  for n in xrange(expected_len, len(line)):
    if line[n] not in ("\r", "\n"):
      eprint("unexpected character %s at %d:%d" % (hex(ord(line[n])), line_nr, n))
      sys.exit(1)

