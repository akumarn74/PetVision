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

  Stream<BackendStatusMessage> connectToInferenceStream() {
    final wsUrl = baseUrl.replaceFirst('http', 'ws');
    final channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/scans'));
    
    return channel.stream.map((rawString) {
      final map = json.decode(rawString);
      return BackendStatusMessage.fromJson(map);
    });
  }
}
