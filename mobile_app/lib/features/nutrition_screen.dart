import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/models.dart';
import '../core/api_client.dart';

class NutritionScreen extends ConsumerStatefulWidget {
  final PetProfile pet;
  const NutritionScreen({super.key, required this.pet});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  final TextEditingController _dietController = TextEditingController();
  bool _isLogging = false;
  late Future<Map<String, dynamic>> _nutritionFuture;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }
  
  void _refreshDashboard() {
    setState(() {
      _nutritionFuture = ref.read(apiClientProvider).getDietRecommendation(widget.pet.id);
    });
  }

  Future<void> _snapMeal() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    
    if (photo == null) return;
    
    setState(() => _isLogging = true);
    try {
      final bytes = await photo.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      await ref.read(apiClientProvider).logDietImage(widget.pet.id, base64Image);
      _refreshDashboard(); // pull the updated DB records + new AI recommendation!
    } catch(e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to parse diet: $e')));
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('${widget.pet.name}\'s Diet', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _nutritionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator(color: Colors.green));
          }
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          
          final data = snapshot.data!;
          final todayKcal = data["today_calories"] ?? 0.0;
          final targetKcal = data["target_calories"] ?? 1000.0;
          final recommendation = data["ai_recommendation"] ?? "Tracking active.";
          final List recentMeals = data["recent_meals"] ?? [];

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Calorie Circular Widget
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 200, height: 200,
                            child: CircularProgressIndicator(
                              value: (todayKcal / targetKcal).clamp(0.0, 1.0),
                              strokeWidth: 16,
                              backgroundColor: Colors.grey[200],
                              color: todayKcal > targetKcal ? Colors.redAccent : Colors.greenAccent.shade400,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(todayKcal.toStringAsFixed(0), style: GoogleFonts.plusJakartaSans(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -2)),
                              Text("of ${targetKcal.toStringAsFixed(0)} kcal", style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // GPT-4o Insight
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3), width: 2),
                        boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.05), blurRadius: 20)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology, color: Colors.green, size: 24),
                              const SizedBox(width: 8),
                              Text("Nutrition Intelligence", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(recommendation, style: GoogleFonts.plusJakartaSans(color: Colors.grey[800], fontSize: 15, height: 1.5, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    Text("Today's Macros", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (recentMeals.isEmpty)
                      Text("No meals logged today.", style: GoogleFonts.plusJakartaSans(color: Colors.grey[400]))
                    else
                      ...recentMeals.map((m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.greenAccent.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.set_meal, color: Colors.green),
                        ),
                        title: Text(m["food_name"], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                        trailing: Text("${m['calories']} kcal", style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontWeight: FontWeight.w800)),
                      )),
                  ],
                ),
              ),

              // NLP Magic Input Field -> Changed to Vision Snap!
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 30, offset: Offset(0, -5))],
                ),
                child: SafeArea(
                  child: InkWell(
                    onTap: _isLogging ? null : _snapMeal,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Center(
                        child: _isLogging 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_alt_rounded, color: Colors.white),
                                const SizedBox(width: 12),
                                Text('SNAP MEAL', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              )
            ],
          );
        }
      ),
    );
  }
}
