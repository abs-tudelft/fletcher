#include <vector>
#include <string>

#include "SodaBeer.h"

int main() {
	std::vector<std::string> hobbiton_names = {"Bilbo", "Rosie", "Frodo", "Sam", "Elanor"};
	std::vector<uint8_t> hobbiton_ages = {111, 32, 33, 35, 1};
	std::vector<std::string> bywater_names = {"Lobelia", "Merry", "Pippin"};
	std::vector<uint8_t> bywater_ages = {80, 37, 29};

	Schema hobbiton;
	Schema bywater;
	Schema soda;
	Schema beer;

	for (int i=0;i<hobbiton_names.size();i++) {
		hobbiton.age << hobbiton_ages[i];
		hobbiton.name_lengths << hobbiton_names[i].size();
		for (int j = 0; j < hobbiton_names[i].size(); j++) {
			hobbiton.name_chars << hobbiton_names[i].c_str()[j];
		}
		ChooseDrink(hobbiton, bywater, soda, beer, 33);
	}

	for (int i=0;i<bywater_names.size();i++) {
		bywater.age << bywater_ages[i];
		bywater.name_lengths << bywater_names[i].size();
		for (int j = 0; j < bywater_names[i].size(); j++) {
			bywater.name_chars << bywater_names[i].c_str()[j];
		}
		ChooseDrink(hobbiton, bywater, soda, beer, 33);
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
