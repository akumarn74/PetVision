import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:camera/camera.dart';
import '../domain/models.dart';

// Riverpod Provider mapping the overarching backend instance universally!
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: 'http://localhost:8000'); 
  // TODO: Use 10.0.2.2 for Android emulators instead of localhost later.
});

// 1. Defining the Riverpod FutureProvider caching our API requests async safely globally.
final petsListProvider = FutureProvider<List<PetProfile>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return await client.getPets();
});

class ApiClient {
  final String baseUrl;
  // A mock JWT Token - realistically provided by FirebaseAuth.instance.currentUser?.getIdToken()
  final String _mockAuthToken = "mock_firebase_signed_in_jwt_token";

  ApiClient({required this.baseUrl});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_mockAuthToken',
      };

  // ===============
  // REST ENDPOINTS
  // ===============
  
  Future<List<PetProfile>> getPets() async {
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
        'Authorization': 'Bearer $_mockAuthToken',
      });
      
    // Because Flutter Web might provide empty paths, we rely on readAsBytes safely natively out of cross_file.
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

  // ==============
  // WEBSOCKETS
  // ==============

  Stream<BackendStatusMessage> connectToInferenceStream() {
    // Note: WebSockets require entirely distinct routing scheme (ws:// vs http://)
    final wsUrl = baseUrl.replaceFirst('http', 'ws');
    final channel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/scans'));
    
    return channel.stream.map((rawString) {
      final map = json.decode(rawString);
      return BackendStatusMessage.fromJson(map);
    });
  }
}
