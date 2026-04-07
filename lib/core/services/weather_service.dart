import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Your provided API Key
  final String _apiKey = "46b5873e1cd1a56563dcbaae4a177de6";

  /// Fetches weather data using coordinates from the Android System
  Future<String> getWeather(double lat, double lon) async {
    try {
      // We use units=metric for Celsius. Change to imperial for Fahrenheit.
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final String cityName = data['name'] ?? "your location";
        final temp = data['main']['temp'].round();
        final description = data['weather'][0]['description'];
        final humidity = data['main']['humidity'];

        // This string is what ARIA will "read" to the user
        return "In $cityName, it's currently $temp°C with $description. Humidity is at $humidity%.";
      } else {
        return "I can't access weather data right now (Error: ${response.statusCode}).";
      }
    } catch (e) {
      print("Weather Service Error: $e");
      return "I'm having trouble connecting to the weather service.";
    }
  }
}
