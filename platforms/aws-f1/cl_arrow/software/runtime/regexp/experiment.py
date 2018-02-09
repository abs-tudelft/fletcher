from subprocess import call

for n in range(4, 24):
    num_strings = 2**n
    call(["./regexp", str(num_strings), '8'])
