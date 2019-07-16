#pragma once

#include "api.h"

/**
 * String utilities
 */

#define MAX_STRING_LENGTH 256

inline void PullString(f_uint8 buffer[MAX_STRING_LENGTH], f_size length, hls::stream<f_uint8> &chars)
{
	for (int i = 0; i < length.data; i++)
	{
		chars >> buffer[i];
	}
}

inline void PushString(f_uint8 buffer[MAX_STRING_LENGTH], f_size length, hls::stream<f_uint8> &chars)
{
	for (int i = 0; i < length.data; i++)
	{
		chars << buffer[i];
	}
}
