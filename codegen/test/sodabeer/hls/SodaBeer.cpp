#include "SodaBeer.h"

#include <hls_stream.h>
#include <inttypes.h>

void PullString(unsigned char buffer[MAX_NAME_LENGTH], unsigned int length, hls::stream<unsigned char>& chars) {
	for (int i = 0; i < length; i++) {
		chars >> buffer[i];
	}
}

void PushString(unsigned char buffer[MAX_NAME_LENGTH], unsigned int length, hls::stream<unsigned char>& chars) {
	for (int i = 0; i < length; i++) {
		chars << buffer[i];
	}
}


bool ChooseDrink(Schema& hobbiton, Schema& bywater, Schema& soda, Schema& beer, unsigned int beer_allowed_age) {
	#pragma HLS INTERFACE register port=beer_allowed_age
	#pragma HLS INTERFACE axis port=hobbiton.name_length
	#pragma HLS INTERFACE axis port=hobbiton.name_chars
	#pragma HLS INTERFACE axis port=hobbiton.age

	#pragma HLS INTERFACE axis port=bywater.name_length
	#pragma HLS INTERFACE axis port=bywater.name_chars
	#pragma HLS INTERFACE axis port=bywater.age

	#pragma HLS INTERFACE axis port=soda.name_length
	#pragma HLS INTERFACE axis port=soda.name_chars
	#pragma HLS INTERFACE axis port=soda.age

	#pragma HLS INTERFACE axis port=beer.name_length
	#pragma HLS INTERFACE axis port=beer.name_chars
	#pragma HLS INTERFACE axis port=beer.age

	bool did_something = false;
	unsigned char name[MAX_NAME_LENGTH];
	unsigned int nlen;
	unsigned char age;

	// Select input stream and pull in a hobbit.
	if (!hobbiton.age.empty()) {
		hobbiton.age >> age;
		hobbiton.name_lengths >> nlen;
		PullString(name, nlen, hobbiton.name_chars);
	} else if (!bywater.age.empty()) {
		bywater.age >> age;
		bywater.name_lengths >> nlen;
		PullString(name, nlen, bywater.name_chars);
	} else {
		// No data ready, just return without doing anything
		goto end;
	}

	// Select output stream and push the hobbit.
	if (age >= beer_allowed_age) {
		beer.age << age;
		beer.name_lengths << nlen;
		PushString(name, nlen, beer.name_chars);
	} else {
		soda.age << age;
		soda.name_lengths << nlen;
		PushString(name, nlen, soda.name_chars);
	}

	did_something = true;

	// End of function
	end:
	return did_something;
}
