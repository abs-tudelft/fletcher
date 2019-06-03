#include <hls_stream.h>
#include <inttypes.h>

#define MAX_NAME_LENGTH 256

struct Schema {
	hls::stream<uint32_t> name_lengths;
	hls::stream<unsigned char> name_chars;
	hls::stream<unsigned char> age;
};

void PullString(unsigned char buffer[MAX_NAME_LENGTH], unsigned int length, hls::stream<unsigned char>& chars);
void PushString(unsigned char buffer[MAX_NAME_LENGTH], unsigned int length, hls::stream<unsigned char>& chars);
bool ChooseDrink(Schema& hobbits, Schema& soda, Schema& beer, unsigned int beer_allowed_age);
