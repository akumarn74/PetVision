import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../domain/models.dart';
import '../core/api_client.dart';

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

  void _showDeltaEducationalModal(String metric, double delta, Color tickerColor, IconData tickerIcon) {
    String contextText = "";
    String trajectoryTip = "";
    final bool isPositive = delta > 0;
    final bool isNeutral = delta == 0;
    
    if (metric == "Body Condition") {
      contextText = "This tracks your pet's muscular mass and fat reserves against their rolling 30-day average.";
      trajectoryTip = isPositive 
          ? "The AI detected an increase in body condition. Ensure they aren't becoming overweight."
          : (isNeutral ? "Consistent structural weight maintained perfectly." : "Minor muscle loss or fat depletion detected. Check their calorie intake.");
    } else if (metric == "Coat Health") {
      contextText = "The AI constantly re-evaluates the pixel luminance and fur texture to map historical shedding or gloss patterns.";
      trajectoryTip = isPositive 
          ? "Gorgeous coat improvement! Your recent dietary choices are working."
          : (isNeutral ? "Consistent coat hydration level." : "A regression in coat health detected. Consider omega-3 supplements or more frequent brushing.");
    } else if (metric == "Eye Clarity") {
      contextText = "We cross-reference current cornea opacity measurements against previous scans to catch micro-cataracts early.";
      trajectoryTip = isPositive 
          ? "Excellent optical clarity improvement, likely decreased tearing."
          : (isNeutral ? "Optics remain stable and clear." : "A negative drop indicates new redness, tearing, or lens opacity. Watch closely.");
    } else if (metric == "Dental Plaque") {
      contextText = "This tracks the algorithm's calculation of calculus bounds along the gumline over time to measure tartar accumulation velocity.";
      trajectoryTip = isPositive 
          ? "Teeth are appearing cleaner relative to the last 30 days! Good brushing."
          : (isNeutral ? "Plaque baseline is stable." : "Accelerated tartar buildup detected relative to history. Time for a dental stick!");
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: tickerColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(tickerIcon, color: tickerColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text("$metric Trend", style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 24),
              Text("30-Day Moving Trajectory: ${isPositive ? '+' : ''}${delta.toStringAsFixed(1)}%", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: tickerColor)),
              const SizedBox(height: 16),
              Text(contextText, style: GoogleFonts.plusJakartaSans(fontSize: 15, height: 1.6, color: Colors.grey[800])),
              
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.analytics_outlined, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Trajectory Analysis", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text(trajectoryTip, style: GoogleFonts.plusJakartaSans(color: Colors.grey[700], height: 1.5, fontSize: 13)),
                        ],
                      )
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),
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
      appBar: AppBar(
        title: Text('${widget.pet.name}\'s Health Trends', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.black, fontSize: 18)),
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
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

                      // Metric Delta Grid
                      _buildSectionTitle(Icons.trending_up_rounded, "30-Day Metric Deltas"),
                      Text("Tap on any trajectory tile for deeper temporal analysis.", style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey[500])),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(child: _buildDeltaCard("Body Condition", trends["body_condition_delta_pct"] ?? 0.0)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDeltaCard("Coat Health", trends["coat_health_delta_pct"] ?? 0.0)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildDeltaCard("Eye Clarity", trends["eye_clarity_delta_pct"] ?? 0.0)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDeltaCard("Dental Plaque", trends["dental_plaque_delta_pct"] ?? 0.0)),
                        ],
                      ),
                      
                      const SizedBox(height: 64),
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

  Widget _buildDeltaCard(String label, dynamic rawDelta) {
    final double delta = (rawDelta is num) ? rawDelta.toDouble() : 0.0;
    final bool isPositive = delta > 0;
    final bool isNeutral = delta == 0;

    final Color tickerColor = isNeutral ? Colors.grey[600]! : (isPositive ? Colors.green.shade600 : Colors.red.shade500);
    final IconData tickerIcon = isNeutral ? Icons.horizontal_rule_rounded : (isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded);

    return Material(
      color: Colors.white,
      shadowColor: Colors.black12,
      elevation: 2,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => _showDeltaEducationalModal(label, delta, tickerColor, tickerIcon),
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
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[800])),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: tickerColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(tickerIcon, color: tickerColor, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${isPositive ? '+' : ''}${delta.toStringAsFixed(1)}%',
                    style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: tickerColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
