import java.util.Random;

public class Person {
	public String first_name;
	public String last_name;
	public int zip_code;
	
	private static final String alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
	private static StringBuilder builder = new StringBuilder(40);
	
	public static Person generateRandomPerson(
			Random rng, int min_length, int max_length,
			int last_name_period, int zip_code_period,
			String special_last_name, int special_zip_code) {
		Person p = new Person();
		
		// First name
		builder.setLength(0);
		int name_len = rng.nextInt(max_length - min_length + 1) + min_length;
		for (int n = 0; n < name_len; n++) {
			int rnd_char = rng.nextInt(alphabet.length());
			builder.append(alphabet.charAt(rnd_char));
		}
		p.first_name = builder.toString();
		
		// Last name
		if(rng.nextInt(Integer.MAX_VALUE) % last_name_period == 0) {
			p.last_name = special_last_name;
		} else {
			builder.setLength(0);
			name_len = rng.nextInt(max_length - min_length + 1) + min_length;
			for (int n = 0; n < name_len; n++) {
				int rnd_char = rng.nextInt(alphabet.length());
				builder.append(alphabet.charAt(rnd_char));
			}
			p.last_name = builder.toString();
		}
		
		// Zip code
		if (rng.nextInt(Integer.MAX_VALUE) % zip_code_period == 0) {
			p.zip_code = special_zip_code;
		} else {
			p.zip_code = rng.nextInt(10000);
		}
		
		return p;
	}
}
