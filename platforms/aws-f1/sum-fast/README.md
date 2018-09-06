# Fast Parallel Summing AWS Project

This is the aws-f1 project for the
[fast parallel sum](../../../examples/sum-fast/) hardware implementation.
For help using this project, see the [README](../sum/README.md)
of the summing example.

This design supports a clock frequency of 250 MHz, which you can set by
choosing the AWS A1 clock recipe when synthesizing:

    $ ./aws_build_dcp_from_cl.sh -foreground -clock_recipe_a A1
