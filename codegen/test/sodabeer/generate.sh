fletchgen -i input/Hobbiton.fbs input/Bywater.fbs input/Soda.fbs input/Beer.fbs \
          -r input/Hobbiton.rb input/Bywater.rb output/Soda.rb output/Beer.rb \
          -s output/Hobbits.srec \
          -t output/SodaBeer.srec \
          -l vhdl \
          --sim
