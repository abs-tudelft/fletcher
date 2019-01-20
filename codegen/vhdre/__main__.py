from . import RegexMatcher

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

if __name__ == "__main__":
    import sys

    def usage():
        print(r"Usage: python -m vhdre <entity-name> <regex> ... [-- <test-string> ...]")
        print(r"")
        print(r"Generates a file by the name <entity-name>.vhd in the working directory")
        print(r"which matches against the given regular expressions. If one or more test")
        print(r"strings are provided, a testbench by the name <entity-name>_tb.vhd is")
        print(r"also generated. To insert a unicode code point, use {0xHHHHHH:u}. To")
        print(r"insert a raw byte (for instance to check error handling) use {0xHH:b}.")
        print(r"{{ and }} can be used for matching { and } literally.")
        sys.exit(2)


    if len(sys.argv) < 3:
        usage()

    # Figure out where the -- is (if it exists).
    split = len(sys.argv)
    for i, arg in enumerate(sys.argv[3:]):
        if arg == "--":
            split = i + 3

    # Generate the matcher.
    matcher = RegexMatcher(*sys.argv[1:split])

    # Generate the main file.
    vhd = str(matcher)
    with open(sys.argv[1] + ".vhd", "w") as f:
        f.write(vhd)

    # Generate the testbench if desired.
    vectors = sys.argv[split + 1:]
    if vectors:
        vhd_tb = matcher.testbench(vectors)
        with open(sys.argv[1] + "_tb.vhd", "w") as f:
            f.write(vhd_tb)