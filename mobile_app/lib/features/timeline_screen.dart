import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models.dart';
import '../core/api_client.dart';
import 'camera_screen.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  final PetProfile pet;
  const TimelineScreen({super.key, required this.pet});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  late Future<Map<String, dynamic>> _trendsFuture;

  @override
  void initState() {
    super.initState();
    _trendsFuture = ref.read(apiClientProvider).getTrends(widget.pet.id);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text('${widget.pet.name}\'s Health Trends', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.black, fontSize: 18)),
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(pet: widget.pet))),
        backgroundColor: Colors.black,
        icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
        label: Text("NEW SCAN", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _trendsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black));
          }

          if (snapshot.hasError) {
             return Center(child: Text("Connection failed: ${snapshot.error}"));
          }

          final Map<String, dynamic> data = snapshot.data ?? {};
          final status = data["status"] ?? "unknown";

          if (status == "insufficient_data" || status == "first_scan") {
            return _buildEmptyState(data["message"] ?? "Not enough data.");
          }

          final Map<String, dynamic> trends = data["trends"] ?? {};
          final List<dynamic> insights = data["insights"] ?? [];
          final Map<String, dynamic> llmContext = data["llm_context"] ?? {};

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Longitudinal AI Engine", style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1)),
                      const SizedBox(height: 8),
                      Text("Comparing your most recent scan against the 30-day moving average.", style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontSize: 16, height: 1.4)),
                      const SizedBox(height: 32),

                      // AI Insights List
                      _buildSectionTitle(Icons.psychology, "Synthesized AI Insights"),
                      const SizedBox(height: 16),
                      ...insights.map((insight) => _buildInsightCard(insight.toString())),

                      const SizedBox(height: 40),

                      // Metric Delta Stream
                      _buildSectionTitle(Icons.trending_up_rounded, "30-Day Metric Deltas"),
                      const SizedBox(height: 16),
                      
                      Column(
                        children: [
                          _buildDeltaCard("Body Condition", trends["body_condition_delta_pct"] ?? 0.0, llmContext),
                          const SizedBox(height: 16),
                          _buildDeltaCard("Coat Health", trends["coat_health_delta_pct"] ?? 0.0, llmContext),
                          const SizedBox(height: 16),
                          _buildDeltaCard("Eye Clarity", trends["eye_clarity_delta_pct"] ?? 0.0, llmContext),
                          const SizedBox(height: 16),
                          _buildDeltaCard("Dental Plaque", trends["dental_plaque_delta_pct"] ?? 0.0, llmContext),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // GENERATE VET REPORT CTA
                      InkWell(
                        onTap: () async {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => _buildVetReportModal(ctx)
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2), width: 2)
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.medical_information_rounded, color: Colors.blueAccent),
                                const SizedBox(width: 12),
                                Text("EXPORT VET REPORT", style: GoogleFonts.plusJakartaSans(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 120), // buffer for FAB
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.show_chart_rounded, size: 64, color: Colors.blueAccent),
            ),
            const SizedBox(height: 24),
            Text("AI Trend Engine Initializing", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontSize: 16, height: 1.5)),
            const SizedBox(height: 32),
            Text("Tip: Perform at least two scans separated by a few days to generate longitudinal moving averages.", textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 24),
        const SizedBox(width: 12),
        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildInsightCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt, color: Colors.amber, size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: GoogleFonts.plusJakartaSans(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildDeltaCard(String metric, dynamic rawDelta, Map<String, dynamic> llmContext) {
    final double delta = (rawDelta is num) ? rawDelta.toDouble() : 0.0;
    final bool isPositive = delta > 0;
    final bool isNeutral = delta == 0;

    final Color tickerColor = isNeutral ? Colors.grey[600]! : (isPositive ? Colors.green.shade600 : Colors.red.shade500);
    final IconData tickerIcon = isNeutral ? Icons.horizontal_rule_rounded : (isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);

    String contextText = "";
    String trajectoryTip = "";
    if (metric == "Body Condition") {
      contextText = llmContext["body_context"] ?? "This tracks your pet's muscular mass and fat reserves against their rolling 30-day average.";
      trajectoryTip = llmContext["body_trajectory"] ?? (isPositive ? "The AI detected an increase in body condition. Ensure they aren't becoming overweight." : (isNeutral ? "Consistent structural weight maintained perfectly." : "Minor muscle loss or fat depletion detected. Check their calorie intake."));
    } else if (metric == "Coat Health") {
      contextText = llmContext["coat_context"] ?? "The AI constantly re-evaluates the pixel luminance and fur texture to map historical shedding or gloss patterns.";
      trajectoryTip = llmContext["coat_trajectory"] ?? (isPositive ? "Gorgeous coat improvement! Your recent dietary choices are working." : (isNeutral ? "Consistent coat hydration level." : "A regression in coat health detected. Consider omega-3 supplements or more frequent brushing."));
    } else if (metric == "Eye Clarity") {
      contextText = llmContext["eye_context"] ?? "We cross-reference current cornea opacity measurements against previous scans to catch micro-cataracts early.";
      trajectoryTip = llmContext["eye_trajectory"] ?? (isPositive ? "Excellent optical clarity improvement, likely decreased tearing." : (isNeutral ? "Optics remain stable and clear." : "A negative drop indicates new redness, tearing, or lens opacity. Watch closely."));
    } else if (metric == "Dental Plaque") {
      contextText = llmContext["dental_context"] ?? "This tracks the algorithm's calculation of calculus bounds along the gumline over time to measure tartar accumulation velocity.";
      trajectoryTip = llmContext["dental_trajectory"] ?? (isPositive ? "Teeth are appearing cleaner relative to the last 30 days! Good brushing." : (isNeutral ? "Plaque baseline is stable." : "Accelerated tartar buildup detected relative to history. Time for a dental stick!"));
    }

    final Color lightGradient = tickerColor.withValues(alpha: 0.05);
    final Color medGradient = tickerColor.withValues(alpha: 0.15);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tickerColor.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: tickerColor.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 12))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Abstract decorative background bubbles
            Positioned(
              right: -40,
              top: -20,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(shape: BoxShape.circle, color: lightGradient),
              )
            ),
            Positioned(
              left: -10,
              bottom: -30,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(shape: BoxShape.circle, color: medGradient),
              )
            ),
            
            // Core UI Feed View
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(metric, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text("30-Day Moving Average", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: tickerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: tickerColor, width: 1.5)
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${isPositive ? '+' : ''}${delta.toStringAsFixed(1)}%',
                              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: tickerColor),
                            ),
                            const SizedBox(width: 8),
                            Icon(tickerIcon, color: tickerColor, size: 20),
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
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.history, color: tickerColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(contextText, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey[700], height: 1.5, fontWeight: FontWeight.w500))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(color: const Color(0xFFF1F5F9), height: 1, width: double.infinity),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.insights, color: Colors.amber.shade600, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(trajectoryTip, style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w700, height: 1.5))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVetReportModal(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32))
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Vet Context Report", style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<String>(
              future: ref.read(apiClientProvider).getVetReport(widget.pet.id),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: Colors.blueAccent),
                    )
                  );
                }
                if (snapshot.hasError) {
                  return Text("Error pulling clinical timeline: ${snapshot.error}", style: TextStyle(color: Colors.red));
                }
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: Text(
                    snapshot.data ?? "Report unavailable.",
                    style: GoogleFonts.plusJakartaSans(color: Colors.black87, fontSize: 16, height: 1.6, fontWeight: FontWeight.w500)
                  ),
                );
              }
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
