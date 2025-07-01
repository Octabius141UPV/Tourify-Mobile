import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PlaceInfo {
  final double? rating;
  final String? address;
  final String? review;

  PlaceInfo({this.rating, this.address, this.review});
}

class PlacesService {
  static Future<PlaceInfo?> getPlaceInfo(String name, String city) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return null;
    final query = '$name, $city';
    // 1. Buscar el place_id
    final searchUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${Uri.encodeComponent(query)}&inputtype=textquery&fields=place_id&key=$apiKey',
    );
    final searchResp = await http.get(searchUrl);
    if (searchResp.statusCode != 200) return null;
    final searchData = json.decode(searchResp.body);
    if (searchData['candidates'] == null || searchData['candidates'].isEmpty) return null;
    final placeId = searchData['candidates'][0]['place_id'];
    // 2. Obtener detalles del lugar
    final detailsUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=rating,formatted_address,reviews&key=$apiKey',
    );
    final detailsResp = await http.get(detailsUrl);
    if (detailsResp.statusCode != 200) return null;
    final detailsData = json.decode(detailsResp.body);
    final result = detailsData['result'];
    final rating = result['rating'] != null ? (result['rating'] as num).toDouble() : null;
    final address = result['formatted_address'] as String?;
    String? review;
    if (result['reviews'] != null && result['reviews'].isNotEmpty) {
      review = result['reviews'][0]['text'];
    }
    return PlaceInfo(rating: rating, address: address, review: review);
  }
} 