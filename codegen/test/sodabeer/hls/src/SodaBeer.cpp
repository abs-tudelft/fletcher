

#include "SodaBeer.h"

bool ChooseDrink(RecordBatchMeta hobbits_meta, Hobbits& hobbits, Soda& soda, Beer& beer, unsigned int beer_allowed_age) {
	#pragma HLS INTERFACE register port=beer_allowed_age
	#pragma HLS INTERFACE register port=hobbits_meta.length

#pragma HLS INTERFACE ap_fifo port=hobbits.name_length
	#pragma HLS data_pack variable=hobbits.name_length
#pragma HLS INTERFACE ap_fifo port=hobbits.name_chars
	#pragma HLS data_pack variable=hobbits.name_chars
#pragma HLS INTERFACE ap_fifo port=hobbits.age
	#pragma HLS data_pack variable=hobbits.age

#pragma HLS INTERFACE ap_fifo port=soda.name_length
	#pragma HLS data_pack variable=soda.name_length
#pragma HLS INTERFACE ap_fifo port=soda.name_chars
	#pragma HLS data_pack variable=soda.name_chars
#pragma HLS INTERFACE ap_fifo port=soda.age
	#pragma HLS data_pack variable=soda.age

#pragma HLS INTERFACE ap_fifo port=beer.name_length
	#pragma HLS data_pack variable=beer.name_length
#pragma HLS INTERFACE ap_fifo port=beer.name_chars
	#pragma HLS data_pack variable=beer.name_chars
#pragma HLS INTERFACE ap_fifo port=beer.age
	#pragma HLS data_pack variable=beer.age

	static int i = 0;

	f_uint8 name[MAX_STRING_LENGTH];
	f_size nlen;
	f_uint8 age;

	i++;

	// Select input stream and pull in a hobbit.
	hobbits.age >> age;
	hobbits.name_lengths >> nlen;
	PullString(name, nlen, hobbits.name_chars);

	// Select output stream and push the hobbit.
	if (age.data >= beer_allowed_age) {
		beer.age << age;
		beer.name_lengths << nlen;
		PushString(name, nlen, beer.name_chars);
	} else {
		soda.age << age;
		soda.name_lengths << nlen;
		PushString(name, nlen, soda.name_chars);
	}

	if (i == hobbits_meta.length) {
		age.SetDataValid(false);
		nlen.SetDataValid(false);
		if (age.data >= beer_allowed_age) {
			soda.age << age;
			soda.name_lengths << nlen;
		} else {
			beer.age << age;
			beer.name_lengths << nlen;
		}
	}

	return true;
}
