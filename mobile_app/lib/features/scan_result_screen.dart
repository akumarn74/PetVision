import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models.dart';
import '../core/api_client.dart';
import 'timeline_screen.dart';

class ScanResultScreen extends ConsumerStatefulWidget {
  final PetProfile pet;
  final PetScanResult result;

  const ScanResultScreen({super.key, required this.pet, required this.result});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> with SingleTickerProviderStateMixin {
  late Future<String> _llmReportFuture;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  // Calculate average overall health out of 100
  double get totalHealthIndex => (
    widget.result.bodyConditionScore +
    widget.result.coatHealthScore + 
    widget.result.eyeClarityScore + 
    widget.result.dentalPlaqueScore
  ) / 4.0;

  @override
  void initState() {
    super.initState();
    // Fetch the AI Vet Synthesis exactly once when the screen loads
    _llmReportFuture = ref.read(apiClientProvider).getVetReport(widget.pet.id);
    
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _progressAnimation = Tween<double>(begin: 0.0, end: totalHealthIndex / 100.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic)
    );
    _progressController.forward();
  }
  
  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  String _getInsight(String metric, double score) {
    Map<String, dynamic> rawJson = {};
    if (widget.result.rawDetections != null) {
      try {
         rawJson = json.decode(widget.result.rawDetections!);
      } catch(e) {}
    }
    
    if (metric == "Body Condition") return rawJson["body_condition_analysis"] ?? "Status Pending: AI data unavailable for this vector.";
    if (metric == "Coat Health") return rawJson["coat_health_analysis"] ?? "Status Pending: AI data unavailable for this vector.";
    if (metric == "Eye Clarity") return rawJson["eye_clarity_analysis"] ?? "Status Pending: AI data unavailable for this vector.";
    if (metric == "Dental Plaque") return rawJson["dental_plaque_analysis"] ?? "Status Pending: AI data unavailable for this vector.";
    return '';
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium Apple-style immersive App Bar
          SliverAppBar(
            expandedHeight: 280.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFFF9FAFB),
            iconTheme: const IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroRadialIndex(),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.psychology, color: Colors.blueAccent, size: 28),
                      const SizedBox(width: 8),
                      Text("AI Veterinary Synthesis", style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -0.5)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // LIVE LLM Vet Report Loading Box
                  _buildLLMInsightsBox(),
                  
                  const SizedBox(height: 48),
                  Text("AI Diagnostic Breakdown", style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Vertical Feed of Metrics
                  Column(
                    children: [
                      _buildDetailCard("Body Condition", widget.result.bodyConditionScore, Colors.blueAccent, Icons.monitor_weight_outlined),
                      const SizedBox(height: 16),
                      _buildDetailCard("Coat Health", widget.result.coatHealthScore, Colors.orangeAccent, Icons.pets_outlined),
                      const SizedBox(height: 16),
                      _buildDetailCard("Eye Clarity", widget.result.eyeClarityScore, Colors.tealAccent.shade400, Icons.remove_red_eye_outlined),
                      const SizedBox(height: 16),
                      _buildDetailCard("Dental Plaque", widget.result.dentalPlaqueScore, Colors.redAccent, Icons.medical_services_outlined),
                    ],
                  ),

                  const SizedBox(height: 64),
                  
                  // Bottom CTA
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context, 
                        MaterialPageRoute(builder: (_) => TimelineScreen(pet: widget.pet))
                      );
                    },
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
                        child: Text('FINALIZE RECORD', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildHeroRadialIndex() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Overall System Score", style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160, height: 160,
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return CircularProgressIndicator(
                        value: _progressAnimation.value,
                        strokeWidth: 14,
                        backgroundColor: Colors.grey[200],
                        color: _progressAnimation.value > 0.8 ? Colors.greenAccent.shade400 : (_progressAnimation.value > 0.6 ? Colors.orangeAccent : Colors.redAccent),
                        strokeCap: StrokeCap.round,
                      );
                    }
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return Text((_progressAnimation.value * 100).toInt().toString(), style: GoogleFonts.plusJakartaSans(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -2));
                      }
                    ),
                    Text("out of 100", style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLLMInsightsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.05), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: FutureBuilder<String>(
        future: _llmReportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: [
                const LinearProgressIndicator(color: Colors.blueAccent, backgroundColor: Color(0xFFEFF6FF)),
                const SizedBox(height: 16),
                Text("Analyzing 6m longitudinal vector data...", style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontStyle: FontStyle.italic)),
              ],
            );
          }
          if (snapshot.hasError) {
            return Text("AI Engine disconnected. Attempting to fall back to static metrics.", style: GoogleFonts.plusJakartaSans(color: Colors.redAccent));
          }
          return Text(
            snapshot.data ?? "Report unavailable.",
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1E293B), fontSize: 16, height: 1.6, fontWeight: FontWeight.w500),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(String title, double score, Color color, IconData icon) {
    // Generate an illustrative background gradient based on the color schema
    final Color lightGradient = color.withValues(alpha: 0.05);
    final Color medGradient = color.withValues(alpha: 0.15);
    
    IconData dynamicHealthIcon = Icons.health_and_safety;
    bool isMissing = score < 0.0;
    
    if (isMissing) {
      dynamicHealthIcon = Icons.visibility_off;
    } else if (score > 85) {
      dynamicHealthIcon = Icons.star_rounded;
    } else if (score > 65) {
      dynamicHealthIcon = Icons.warning_rounded;
    } else {
      dynamicHealthIcon = Icons.dangerous_rounded;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Abstract decorative backgrounds
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: lightGradient),
              )
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, color: medGradient),
              )
            ),
            // Core Interface Layout
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]),
                              shape: BoxShape.circle,
                              border: Border.all(color: color.withValues(alpha: 0.5)),
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text("AI Extracted Metric", style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                            ],
                          )
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMissing ? Colors.grey.shade200 : (score > 85 ? Colors.greenAccent.withValues(alpha: 0.15) : (score > 65 ? Colors.orangeAccent.withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.15))),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isMissing ? Colors.grey.shade400 : (score > 85 ? Colors.green : (score > 65 ? Colors.orange : Colors.red)), width: 1)
                        ),
                        child: Row(
                          children: [
                            Text(isMissing ? "N/A" : score.toStringAsFixed(1), style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: isMissing ? Colors.grey.shade700 : (score > 85 ? Colors.green.shade700 : (score > 65 ? Colors.orange.shade700 : Colors.red.shade700)))),
                            const SizedBox(width: 4),
                            Icon(dynamicHealthIcon, color: isMissing ? Colors.grey.shade700 : (score > 85 ? Colors.green.shade700 : (score > 65 ? Colors.orange.shade700 : Colors.red.shade700)), size: 16)
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.psychology_alt, color: color, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(_getInsight(title, score), style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.grey[800], height: 1.6, fontWeight: FontWeight.w500)),
                        )
                      ],
                    )
                  ),
                ],
              ),
            ),
          ],
        ),
      )
    );
  }
}
