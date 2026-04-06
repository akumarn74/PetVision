import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_client.dart';

class AddPetScreen extends ConsumerStatefulWidget {
  const AddPetScreen({super.key});

  @override
  ConsumerState<AddPetScreen> createState() => _AddPetScreenState();
}

class _AddPetScreenState extends ConsumerState<AddPetScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _breed = '';
  int _age = 0;
  double _weight = 0.0;
  bool _isLoading = false;

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);
      try {
        final client = ref.read(apiClientProvider);
        await client.createPet(_name, _breed, _age, _weight);
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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('New Pet Profile', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.black, fontSize: 20)),
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Let's get started", style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -1)),
                const SizedBox(height: 8),
                Text("We need a few details to configure the AI model.", style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontSize: 16)),
                const SizedBox(height: 48),
                
                _buildCleanTextField('Pet Name', (v) => _name = v!, hint: "e.g. Luna"),
                const SizedBox(height: 24),
                _buildCleanTextField('Breed', (v) => _breed = v!, hint: "e.g. Golden Retriever"),
                const SizedBox(height: 24),
                _buildCleanTextField('Age (Months)', (v) => _age = int.parse(v!), isNumber: true, hint: "e.g. 24"),
                const SizedBox(height: 24),
                _buildCleanTextField('Current Weight (lbs)', (v) => _weight = double.parse(v!), isNumber: true, hint: "e.g. 45.5"),
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
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, 10))],
                          ),
                          child: Center(
                            child: Text('CREATE PROFILE', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.0)),
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

  Widget _buildCleanTextField(String label, Function(String?) onSave, {bool isNumber = false, String hint = ""}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: TextFormField(
            style: GoogleFonts.plusJakartaSans(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onSaved: onSave,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
          ),
        ),
      ],
    );
  }
}
