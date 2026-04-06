import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models.dart';
import '../core/api_client.dart';

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
    if (metric == "Body Condition") {
      if (score > 85) return 'Ideal muscle-to-fat alignment. Ribs are palpable but not visible.';
      if (score > 65) return 'Slightly misaligned weight class. Recommend diet review quickly.';
      return 'Severe weight anomaly. Consult vet for obesity or malnourishment markers.';
    } else if (metric == "Coat Health") {
      if (score > 85) return 'Sleek, glossy coat indicating excellent systematic nutrition.';
      if (score > 65) return 'Slight matting or dryness detected in fur clusters.';
      return 'Severe shedding, bald spots, or parasitic markers detected.';
    } else if (metric == "Eye Clarity") {
      if (score > 85) return 'Zero lens opacity or tearing. Extremely healthy optics.';
      if (score > 65) return 'Mild discharge or redness around the sclera detected.';
      return 'High opacity/cataract risk. Veterinary ocular assessment required.';
    } else if (metric == "Dental Plaque") {
      if (score > 85) return 'Minimal tartar buildup across visible periodontal boundaries.';
      if (score > 65) return 'Moderate yellowing detected. Regular brushing advised.';
      return 'Severe plaque accumulation. Scaling and polishing strongly recommended.';
    }
    return '';
  }

  void _showEducationalModal(String metric, double score, Color color, IconData icon) {
    String meaning = "";
    String tip = "";
    if (metric == "Body Condition") {
      meaning = "Body Condition is a strictly algorithmic measurement comparing your pet's visible muscular mass against their skeletal framework. This helps determine if they are structurally absorbing nutrients correctly.";
      tip = "Maintain a high-protein diet and ensure at least 30 minutes of aerobic exercise daily.";
    } else if (metric == "Coat Health") {
      meaning = "The AI analyzes pixel-level light reflection gradients and texture distributions. A dull coat often points to hidden systematic dehydration or omega-3 deficiencies.";
      tip = "Supplement with fish oil and brush daily to distribute natural dermal oils.";
    } else if (metric == "Eye Clarity") {
      meaning = "We scan the cornea and sclera for asymmetrical reflections, which are early predictors of cataracts, glaucoma, or underlying hypertension leaks.";
      tip = "Wipe tear stains organically and keep away from high-dust environments.";
    } else if (metric == "Dental Plaque") {
      meaning = "Our vision edge-detection isolates the tartar boundary between the enamel and gumline. Dental disease is directly correlated to fatal heart conditions in aging pets.";
      tip = "Use an enzymatic toothpaste 3x a week, and offer veterinary compressed chewables.";
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text("$metric Context", style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 24),
              // What the AI is doing
              Text("How the AI scored this: ${score.toStringAsFixed(1)} / 100", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 16),
              Text(meaning, style: GoogleFonts.plusJakartaSans(fontSize: 15, height: 1.6, color: Colors.grey[800])),
              
              const SizedBox(height: 32),
              // Doctor Tip
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Recommended Action", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text(tip, style: GoogleFonts.plusJakartaSans(color: Colors.grey[700], height: 1.5, fontSize: 13)),
                        ],
                      )
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Close button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Understood", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ]
          )
        );
      }
    );
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
                  Text("GPT-4o Vision Extracted Metrics", style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Tap on any tile to learn how the AI calculated it.", style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey[500])),
                  const SizedBox(height: 16),
                  
                  // Bento Box 2x2 Grid
                  Row(
                    children: [
                      Expanded(child: _buildBentoCard("Body Condition", widget.result.bodyConditionScore, Colors.blueAccent, Icons.monitor_weight_outlined)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildBentoCard("Coat Health", widget.result.coatHealthScore, Colors.orangeAccent, Icons.pets_outlined)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildBentoCard("Eye Clarity", widget.result.eyeClarityScore, Colors.tealAccent.shade400, Icons.remove_red_eye_outlined)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildBentoCard("Dental Plaque", widget.result.dentalPlaqueScore, Colors.redAccent, Icons.medical_services_outlined)),
                    ],
                  ),

                  const SizedBox(height: 64),
                  
                  // Bottom CTA
                  InkWell(
                    onTap: () => Navigator.pop(context),
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

  Widget _buildBentoCard(String title, double score, Color color, IconData icon) {
    return Material(
      color: Colors.white,
      shadowColor: Colors.black12,
      elevation: 2,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => _showEducationalModal(title, score, color, icon),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Text(score.toStringAsFixed(0), style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              const SizedBox(height: 8),
              Text(_getInsight(title, score), style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[500], height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}
