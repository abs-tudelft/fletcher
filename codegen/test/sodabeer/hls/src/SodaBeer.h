#include <hls_stream.h>
#include <hls_math.h>
#include <ap_int.h>

#include "fletcher/vivado_hls.h"

struct Hobbits {
	hls::stream<f_size> name_lengths;
	hls::stream<f_uint8> name_chars;
	hls::stream<f_uint8> age;
};

struct Soda {
	hls::stream<f_size> name_lengths;
	hls::stream<f_uint8> name_chars;
	hls::stream<f_uint8> age;
};

struct Beer {
	hls::stream<f_size> name_lengths;
	hls::stream<f_uint8> name_chars;
	hls::stream<f_uint8> age;
};

bool ChooseDrink(RecordBatchMeta hobbits_meta, Hobbits& hobbits, Soda& soda, Beer& beer, unsigned int beer_allowed_age);
