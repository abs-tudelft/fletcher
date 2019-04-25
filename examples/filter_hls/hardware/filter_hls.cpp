#include <cstring>
#include <ap_int.h>
#include <hls_stream.h>

int filter_hls_normal(const int num_entries,
                      const int *in_first_name_offsets,
                      const char *in_first_name_values,
                      const int *in_last_name_offsets,
                      const char *in_last_name_values,
                      const int *in_zipcode,

                      const char filter_name[64],
                      const int filter_zipcode,

                      int *out_first_name_offsets,
                      char *out_first_name_values) {

#pragma HLS INTERFACE ap_bus latency=25 port=in_first_name_offsets
#pragma HLS INTERFACE ap_bus latency=25 port=in_first_name_values
#pragma HLS INTERFACE ap_bus latency=25 port=in_last_name_offsets
#pragma HLS INTERFACE ap_bus latency=25 port=in_last_name_values
#pragma HLS INTERFACE ap_bus latency=25 port=out_first_name_offsets
#pragma HLS INTERFACE ap_bus latency=25 port=out_first_name_values

  // Name length buffers
  int fn_strlen = 0;
  int ln_strlen = 0;

  int fn_offset = 0;
  int ln_offset = 0;

  // Name buffers
  char fn_buffer[64];
  char ln_buffer[64];

  // Zip code buffer
  int zip = 0;

  int offset_index = 0;
  int offset_value = 0;

  // Write first offset
  out_first_name_offsets[offset_index] = offset_value;

  for_each_entry: for (int e = 0; e < num_entries; e++) {
    // Assume a match
    bool match = true;

    // Get string lengths
    fn_strlen = in_first_name_offsets[e + 1] - in_first_name_offsets[e];
    ln_strlen = in_last_name_offsets[e + 1] - in_last_name_offsets[e];

    // Get zip
    zip = in_zipcode[e];

    // Copy over to buffers
    memcpy(ln_buffer, in_last_name_values + ln_offset, ln_strlen);
    memcpy(fn_buffer, in_first_name_values + fn_offset, fn_strlen);

    // Check if the last name matches
    match_last_name: for (int c = 0; c < ln_strlen; c++) {
      if (ln_buffer[c] != filter_name[c]) {
        match = false;
      }
    }

    if_match: if (match) {
      memcpy(fn_buffer, out_first_name_values + offset_value, fn_strlen);
      offset_value += fn_strlen;
      offset_index++;
      out_first_name_offsets[offset_index] = offset_value;
    }
  }

  return 0;
}

int filter_hls_fletcher(int num_entries,

                        hls::stream<int> &in_first_name_length,
                        hls::stream<char> &in_first_name_values,
                        hls::stream<int> &in_last_name_length,
                        hls::stream<char> &in_last_name_values,
                        hls::stream<int> &in_zipcode,

                        char filter_name[64],
                        int filter_zipcode,

                        hls::stream<int> &out_first_name_length,
                        hls::stream<char> &out_first_name_values) {

  int matches = 0;

  // Name length buffers
  int fn_strlen = 0;
  int ln_strlen = 0;

  // Name buffers
  char fn_buffer[64];
  char fn_char;

  // Zip code buffer
  int zip;

  for_each_entry:
  for (int e = 0; e < num_entries; e++) {
	// Assume the filter matches
	bool match = true;

    // Grab the lengths and zip code
    in_first_name_length >> fn_strlen;
    in_last_name_length  >> ln_strlen;
    in_zipcode 			 >> zip;

    // Buffer the names
    int fc = 0;

    for_get_fn:
    for (fc = 0; fc < fn_strlen; fc++) {
      in_first_name_values >> fn_buffer[fc];
    }
    // Make sure to terminate the string
    if (fc != 63) {
    	fn_buffer[fc+1] = '\0';
    }

    for_get_ln:
    for (int c = 0; c < ln_strlen; c++) {
      char lnc = '\1';
      in_last_name_values >> lnc;
      // As the characters stream in...
      // Check the first filter condition:
      // last name equal to filter name
      match_name:
      if (lnc != filter_name[c]) {
        match = false;
      }
    }

    // Check the second filter condition: zip code
    match_zip:
    if (zip != filter_zipcode) {
      match = false;
    }

    // Only output the first names if the match was true
    if (match) {
      matches++;
      // Output the string length
	  out_first_name_length << fn_strlen;

      // Output the characters
      for_put_fn:
      for (int c = 0; c < fn_strlen; c++) {
        out_first_name_values << fn_buffer[c];
      }
    }
  }

  return matches;
}
