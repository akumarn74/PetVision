import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';

// Riverpod Provider for Authentication State!
class AuthNotifier extends StateNotifier<String?> {
  AuthNotifier() : super(null) {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('jwt_token');
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    state = token;
  }
  
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, String?>((ref) => AuthNotifier());

// API Client Provider dynamically binds to Auth Token!
final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authProvider);
  return ApiClient(baseUrl: 'http://localhost:8000', authToken: token); 
});

final petsListProvider = FutureProvider<List<PetProfile>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return await client.getPets();
});

class ApiClient {
  final String baseUrl;
  final String? authToken;

  ApiClient({required this.baseUrl, this.authToken});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  // ===============
  // AUTH ENDPOINTS
  // ===============

  Future<String> register(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({"email": email, "password": password})
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['access_token'];
    }
    throw Exception(json.decode(response.body)['detail'] ?? 'Registration Failed');
  }

  Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({"email": email, "password": password})
    );
    if (response.statusCode == 200) {
      return json.decode(response.body)['access_token'];
    }
    throw Exception(json.decode(response.body)['detail'] ?? 'Login Failed');
  }

  // ===============
  // REST ENDPOINTS
  // ===============
  
  Future<List<PetProfile>> getPets() async {
    if (authToken == null) return []; // Auto-block unauthenticated requests natively
    final response = await http.get(Uri.parse('$baseUrl/api/pets'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => PetProfile.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load pets');
    }
  }

  Future<List<PetProfile>> getLeaderboard() async {
    final response = await http.get(Uri.parse('$baseUrl/api/leaderboard'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => PetProfile.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load leaderboard');
    }
  }

  Future<List<FoodCatalogItem>> searchPredefinedFoods(String query) async {
    final response = await http.get(Uri.parse('$baseUrl/api/nutrition/search?q=$query'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((j) => FoodCatalogItem.fromJson(j)).toList();
    }
    return [];
  }

  Future<void> logPredefinedFood(String petId, String foodId) async {
    final body = json.encode({"food_id": foodId});
    final response = await http.post(
      Uri.parse('$baseUrl/api/nutrition/log_predefined/$petId'),
      headers: _headers,
      body: body,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to log predefined food');
    }
  }

  Future<void> deleteDietEntry(String entryId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/nutrition/$entryId'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete diet entry');
    }
  }

  Future<void> createPet(String name, String breed, int ageMonths, double weight) async {
    final body = json.encode({
      "name": name,
      "breed": breed,
      "age_months": ageMonths,
      "baseline_weight": weight
    });
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/pets'), 
      headers: _headers,
      body: body
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to create pet. ${response.body}');
    }
  }

  Future<void> joinPetHousehold(String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/pets/join'),
      headers: _headers,
      body: json.encode({"join_code": code}),
    );
    if (response.statusCode != 200) {
      throw Exception(json.decode(response.body)['detail'] ?? 'Failed to join pet household');
    }
  }

  Future<Map<String, dynamic>> autoDetectPet(XFile file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/pets/auto-detect'))
      ..headers.addAll({if (authToken != null) 'Authorization': 'Bearer $authToken'});
      
    final bytes = await file.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to auto-detect pet attributes: ${response.body}');
  }

  Future<PetScanResult> uploadScan(String petId, XFile file) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/scans/$petId'))
      ..headers.addAll({
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      });
      
    final bytes = await file.readAsBytes();
    final multipartFile = http.MultipartFile.fromBytes(
      'file', 
      bytes, 
      filename: file.name
    );
    
    request.files.add(multipartFile);
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      return PetScanResult.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to upload pet scan: ${response.body}');
    }
  }

  Future<List<PetScanResult>> getPetScans(String petId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/pets/$petId/scans'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => PetScanResult.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch historic scans');
    }
  }

  Future<Map<String, dynamic>> getTrends(String petId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/scans/$petId/trends'), headers: _headers);
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to fetch trends');
  }

  Future<String> getVetReport(String petId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/scans/$petId/vet_report'), headers: _headers);
    if (response.statusCode == 200) return json.decode(response.body)['vet_report'];
    throw Exception('Failed to fetch Vet PDF summary');
  }

  Future<String> getDailyPush(String petId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/notifications/daily/$petId'), headers: _headers);
    if (response.statusCode == 200) return json.decode(response.body)['message'];
    throw Exception('Failed to fetch daily push message');
  }

  Future<int> getStreak() async {
    if (authToken == null) return 0;
    final response = await http.get(Uri.parse('$baseUrl/api/users/streak'), headers: _headers);
    if (response.statusCode == 200) return json.decode(response.body)['streak'];
    return 0; // Fail silently if gamification engine drops
  }

  Future<void> logDietMeal(String petId, String foodDescription) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/nutrition/log/$petId'),
      headers: _headers,
      body: json.encode({"raw_text": foodDescription}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to log nutrition: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getDietRecommendation(String petId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/nutrition/recommendation/$petId'), headers: _headers);
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to pull Cal AI tracking hook');
  }

  Future<void> setupPetDiet(String petId, String activityLevel, String dietGoal) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/nutrition/setup/$petId'),
      headers: _headers,
      body: json.encode({"activity_level": activityLevel, "diet_goal": dietGoal}),
    );
    if (response.statusCode != 200) throw Exception('Failed to setup diet');
  }

  Future<void> logDietImage(String petId, String base64Image) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/nutrition/log_image/$petId'),
      headers: _headers,
      body: json.encode({"image_base64": base64Image}),
    );
    if (response.statusCode != 200) throw Exception('Failed to invoke Vision Nutrition Engine');
  }

  Stream<BackendStatusMessage> connectToInferenceStream() {
    final wsUrl = baseUrl.replaceFirst('http', 'ws');
    final channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/scans'));
    
    return channel.stream.map((rawString) {
      final map = json.decode(rawString);
      return BackendStatusMessage.fromJson(map);
    });
  }
}
