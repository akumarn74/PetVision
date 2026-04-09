import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models.dart';
import '../core/api_client.dart';
import 'nutrition_screen.dart';

class NutritionOnboardingScreen extends ConsumerStatefulWidget {
  final PetProfile pet;
  const NutritionOnboardingScreen({super.key, required this.pet});

  @override
  ConsumerState<NutritionOnboardingScreen> createState() => _NutritionOnboardingScreenState();
}

class _NutritionOnboardingScreenState extends ConsumerState<NutritionOnboardingScreen> {
  String _selectedActivity = "moderate";
  String _selectedGoal = "maintain";
  bool _isProcessing = false;

  void _onComplete() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(apiClientProvider).setupPetDiet(widget.pet.id, _selectedActivity, _selectedGoal);
      
      // Navigate to the Dashboard!
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NutritionScreen(pet: widget.pet)));
    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to calculate tracking budget. $e')));
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        title: Text("Dietary Baseline", style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          children: [
            Text("Set the Baseline", style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1)),
              const SizedBox(height: 8),
              Text("Our AI calculates an exact caloric target mapped directly to ${widget.pet.name}'s breed profile.", style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey[700], height: 1.4)),
              const SizedBox(height: 32),
              
              Text("Activity Level", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 12),
              _buildSelector("couch_potato", "Couch Potato", "Mostly sleeps. Short walks.", _selectedActivity, (v) => setState(() => _selectedActivity = v)),
              const SizedBox(height: 8),
              _buildSelector("moderate", "Moderate", "1-2 hrs of active play/walking daily.", _selectedActivity, (v) => setState(() => _selectedActivity = v)),
              const SizedBox(height: 8),
              _buildSelector("active", "Highly Active", "Working dog / running companion.", _selectedActivity, (v) => setState(() => _selectedActivity = v)),
              
              const SizedBox(height: 32),
              Text("Dietary Goal", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 12),
              _buildSelector("lose_weight", "Lose Weight", "Create a caloric deficit.", _selectedGoal, (v) => setState(() => _selectedGoal = v)),
              const SizedBox(height: 8),
              _buildSelector("maintain", "Maintain Status", "Keep their current weight steady.", _selectedGoal, (v) => setState(() => _selectedGoal = v)),
              const SizedBox(height: 8),
              _buildSelector("gain_weight", "Gain Mass", "Increase caloric intake for growth.", _selectedGoal, (v) => setState(() => _selectedGoal = v)),
              
              const SizedBox(height: 32),
              
              // Submit button
              InkWell(
                onTap: _isProcessing ? null : _onComplete,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Center(
                    child: _isProcessing 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text('GENERATE CALORIE BUDGET', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
                  ),
                ),
              ),
            ],
        ),
      )
    );
  }

  Widget _buildSelector(String value, String title, String subtitle, String groupValue, Function(String) onTap) {
    bool isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF22C55E) : Colors.transparent, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.1), blurRadius: 10)] : [],
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? const Color(0xFF22C55E) : Colors.grey[400]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                  Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
