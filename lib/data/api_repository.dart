import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiRepository {
  Future<String> getBodyDescription(String name) async {
    // Map celestial body names to their precise Wikipedia titles.
    final Map<String, String> wikiTitles = {
      'Sun': 'Sun',
      'Moon': 'Moon',
      'Mercury': 'Mercury_(planet)',
      'Venus': 'Venus',
      'Earth': 'Earth',
      'Mars': 'Mars',
      'Jupiter': 'Jupiter',
      'Saturn': 'Saturn',
      'Uranus': 'Uranus',
      'Neptune': 'Neptune',
      'Andromeda Galaxy': 'Andromeda_Galaxy',
      'Orion Nebula': 'Orion_Nebula',
      'Pleiades': 'Pleiades',
      'Sirius (Star)': 'Sirius',
      'Betelgeuse (Star)': 'Betelgeuse',
      'Polaris (North Star)': 'Polaris',
    };

    final title = wikiTitles[name] ?? name.replaceAll(' ', '_');

    try {
      final response = await http.get(Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$title'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return "${data['description'] ?? 'Celestial Object'}\n\n${data['extract'] ?? 'No detailed description available.'}";
      }
      return "No detailed description available for $name.";
    } catch (e) {
      return "Error fetching data for $name. Please check your internet connection.";
    }
  }
}
