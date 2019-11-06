
import random
import sys

from ArrayReaderTbGen.fields import *
from ArrayReaderTbGen.arrayreader import *

# Figure out a seed to use.
if len(sys.argv) > 1:
    seed = sys.argv[1]
    try:
        seed = int(seed)
    except ValueError:
        seed = hash(seed)
else:
    seed = random.randrange(1 << 32)

# Seed the random generator with it.
random.seed(seed)

# Generate a random field for the array.
while True:
    array = Field.randomized()
    if not array.is_null():
        break

# Generate the reader.
reader = ArrayReader(array, instance_prefix="")

# Output the testbench.
print(reader.testbench(
    seed=seed,
    row_count=100,
    cmd_count=10,
    #addr_width=32,
    #len_width=8,
    #data_width=16,
    #burst_len=4,
    #tag_width=4,
    #random_busreq_timing=False,
    #random_busresp_timing=False,
    #multi_clk=True
))


