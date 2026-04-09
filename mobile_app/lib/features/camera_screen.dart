import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_client.dart';
import '../domain/models.dart';
import 'scan_result_screen.dart';
import 'paywall_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  final PetProfile pet;
  const CameraScreen({super.key, required this.pet});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isUploading = false;
  
  // Real-time AI Status Stream listener
  StreamSubscription<BackendStatusMessage>? _socketSubscription;
  String _currentAiStatus = "Awaiting Capture";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _controller = CameraController(
          _cameras.first, // Uses primary rear camera or default webcam in Chrome
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _controller!.initialize();
      }
    } catch (e) {
      debugPrint('Camera Error: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized || _isUploading) return;
    
    final XFile imageFile = await _controller!.takePicture();
    await _submitImage(imageFile);
  }

  Future<void> _uploadFromGallery() async {
    if (_isUploading) return;
    
    final picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (imageFile != null) {
      await _submitImage(imageFile);
    }
  }

  Future<void> _submitImage(XFile imageFile) async {
    setState(() {
      _isUploading = true;
      _currentAiStatus = "Extracting Frame...";
    });

    try {
      // 1. Hook up the AI Pipeline WebSocket to listen to Python YOLO events
      final client = ref.read(apiClientProvider);
      final stream = client.connectToInferenceStream();
      _socketSubscription = stream.listen((message) {
        if (mounted) {
          setState(() {
            _currentAiStatus = message.message;
          });
        }
      });
      
      setState(() => _currentAiStatus = "Transmitting to Python Server...");

      // 3. Multipart Upload
      final PetScanResult result = await client.uploadScan(widget.pet.id, imageFile);
      
      // 4. Navigate flawlessly to the Result analytics UI
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => ScanResultScreen(pet: widget.pet, result: result))
        );
      }
      
    } catch (e) {
      if (mounted) {
        String errorString = e.toString();
        setState(() {
          _isUploading = false;
          _currentAiStatus = "Capture Failed";
        });
        
        if (errorString.contains("IDENTITY MISMATCH")) {
          // Extract the exact reason formulated by GPT-4o
          String reason = errorString.split("IDENTITY MISMATCH:").last.trim();
          reason = reason.replaceAll('"}', '').replaceAll('\\"', '"').trim();
          
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
                  const SizedBox(width: 12),
                  Text("Verification Failed", style: GoogleFonts.plusJakartaSans(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              content: Text(reason, style: GoogleFonts.plusJakartaSans(color: Colors.grey[700], fontSize: 16, height: 1.5)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("TRY AGAIN", style: GoogleFonts.plusJakartaSans(color: Colors.blueAccent, fontWeight: FontWeight.w800)),
                )
              ],
            )
          );
        } else if (errorString.contains("402")) {
          // Free limits exceeded, route to Monetization hook!
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => const PaywallScreen()
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inference Error: $errorString')));
        }
      }
    } finally {
      _socketSubscription?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(
          child: Text("Camera Hardware Unavailable", style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The Underlying Camera WebRTC Viewfinder
          CameraPreview(_controller!),
          
          // The UI Overlay (Alignment Boxes & Dark Gradient Mask)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent, Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
            ),
          ),
          
          // Pet Alignment Target Reticle
          Center(
            child: Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                border: Border.all(color: _isUploading ? Colors.blueAccent : Colors.white54, width: 2, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(24),
              ),
              child: _isUploading 
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : const SizedBox.shrink(),
            ),
          ),

          // Top App Bar Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                Text("Align ${widget.pet.name} inside frame", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(width: 30), // Padding
              ],
            ),
          ),

          // Bottom Action Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_isUploading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                      child: Text(_currentAiStatus, style: GoogleFonts.plusJakartaSans(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Empty space equivalent to Gallery button to center the capture button
                    const SizedBox(width: 64),
                    
                    GestureDetector(
                      onTap: _captureAndAnalyze,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 80, width: 80,
                        decoration: BoxDecoration(
                          color: _isUploading ? Colors.grey[800] : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white38, width: 6),
                        ),
                        child: _isUploading ? const Icon(Icons.lock, color: Colors.white54) : null,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Gallery Upload Button
                    IconButton(
                      icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 32),
                      onPressed: _uploadFromGallery,
                      padding: const EdgeInsets.all(16),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
