import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_client.dart';

class AddPetScreen extends ConsumerStatefulWidget {
  const AddPetScreen({super.key});

  @override
  ConsumerState<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends ConsumerState<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  
  bool _isLoading = false;
  bool _isAutoDetecting = false;
  
  // Gamification Loop
  int _selectedAvatar = 0;
  final List<String> _avatars = ['🐶', '🐱', '🐰', '🦊', '🐷'];

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _triggerMagicDetect() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    
    setState(() => _isAutoDetecting = true);
    try {
      final client = ref.read(apiClientProvider);
      final aiData = await client.autoDetectPet(image);
      
      setState(() {
        if (aiData['breed'] != null) {
          _breedController.text = aiData['breed'].toString();
        }
        if (aiData['weight_lbs'] != null) {
          _weightController.text = aiData['weight_lbs'].toString();
        }
        if (aiData['vibe_emoji'] != null) {
          final emoji = aiData['vibe_emoji'].toString();
          final index = _avatars.indexOf(emoji);
          if (index != -1) {
            _selectedAvatar = index;
          } else {
            // Expand array dynamically if AI hallucinates a cool emoji
            _avatars.add(emoji);
            _selectedAvatar = _avatars.length - 1;
          }
        }
      });
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI auto-filled out the details! 🚀'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Magic Detect Failed: $e')));
    } finally {
      if (mounted) setState(() => _isAutoDetecting = false);
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final client = ref.read(apiClientProvider);
        await client.createPet(
          _nameController.text, 
          _breedController.text, 
          int.tryParse(_ageController.text) ?? 0, 
          double.tryParse(_weightController.text) ?? 0.0
        );
        ref.invalidate(petsListProvider);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('New Pet Profile', style: Theme.of(context).textTheme.headlineMedium),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Form(
             key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Let's get started", style: Theme.of(context).textTheme.displayMedium),
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                Text("We need a few details to configure the AI model.", style: Theme.of(context).textTheme.bodyLarge),
                SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                
                // MAGIC DETECT BUTTON
                InkWell(
                  onTap: _isAutoDetecting ? null : _triggerMagicDetect,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.deepPurpleAccent, Colors.blueAccent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.deepPurpleAccent.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
                      ]
                    ),
                    child: Center(
                      child: _isAutoDetecting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
                                const SizedBox(width: 12),
                                Text("📸 MAGIC DETECT WITH AI", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                              ],
                            ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // GAMIFIED AVATAR ROW
                Text("Pick their Vibe", style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black87)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_avatars.length, (index) {
                    final bool isSelected = _selectedAvatar == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatar = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Colors.black : const Color(0xFFE2E8F0), width: 2),
                          boxShadow: isSelected ? const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))] : [],
                        ),
                        child: Center(
                          child: Text(
                            _avatars[index],
                            style: TextStyle(fontSize: isSelected ? 32 : 24),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 32),
                
                _buildCleanTextField('Pet Name', _nameController, hint: "e.g. Luna"),
                const SizedBox(height: 24),
                _buildCleanTextField('Breed', _breedController, hint: "e.g. Golden Retriever"),
                const SizedBox(height: 24),
                _buildCleanTextField('Age (Months)', _ageController, isNumber: true, hint: "e.g. 24"),
                const SizedBox(height: 24),
                _buildCleanTextField('Current Weight (lbs)', _weightController, isNumber: true, hint: "e.g. 45.5"),
                const SizedBox(height: 64),
                
                _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.black))
                    : InkWell(
                        onTap: _submit,
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
                          ),
                          child: Center(
                            child: Text('CREATE PROFILE', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCleanTextField(String label, TextEditingController controller, {bool isNumber = false, String hint = ""}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: TextFormField(
            controller: controller,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : [],
            validator: (v) => v!.isEmpty ? 'Required' : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[400], fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
          ),
        ),
      ],
    );
  }
}
