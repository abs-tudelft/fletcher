#include <vector>
#include <string>

#include "SodaBeer.h"

int main() {
	std::vector<std::string> hobbits_names = {"Bilbo", "Rosie", "Frodo", "Sam", "Elanor", "Lobelia", "Merry", "Pippin"};
	std::vector<uint8_t> hobbits_ages = {111, 32, 33, 35, 1, 80, 37, 29};

	Schema hobbits;
	Schema soda;
	Schema beer;

	for (int i=0;i<hobbits_names.size();i++) {
		hobbits.age << hobbits_ages[i];
		hobbits.name_lengths << hobbits_names[i].size();
		for (int j = 0; j < hobbits_names[i].size(); j++) {
			hobbits.name_chars << hobbits_names[i].c_str()[j];
		}
		ChooseDrink(hobbits, soda, beer, 33);
	}

	unsigned char age;
	unsigned int length;
	unsigned char c;

	printf("Hobbits drinking soda:\n");

	while (!soda.age.empty()) {
		soda.age >> age;
		soda.name_lengths >> length;
		for (int j = 0; j < length; j++) {
			soda.name_chars >> c;
			putchar(c);
		}
		printf(" (%d)\n", age);
	}

	printf("Hobbits drinking beer:\n");
	while (!beer.age.empty()) {
		beer.age >> age;
		beer.name_lengths >> length;
		for (int j = 0; j < length; j++) {
			beer.name_chars >> c;
			putchar(c);
		}
		printf(" (%d)\n", age);
	}
}
