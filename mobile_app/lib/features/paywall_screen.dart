import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Aesthetic
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black, const Color(0xFF1E3A8A).withValues(alpha: 0.3), Colors.black],
                )
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text("SCAN QUOTA EXCEEDED", style: GoogleFonts.plusJakartaSans(color: Colors.amberAccent, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Upgrade to\nPetVision Pro",
                    style: GoogleFonts.plusJakartaSans(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You've reached your free 10-scan limit for this month. Unlock unlimited Multi-Modal AI vectors, longitudinal trends, and infinite Vet Exports.",
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey[400], height: 1.5),
                  ),
                  const SizedBox(height: 48),
                  
                  _buildFeatureRow(Icons.camera_alt, "Unlimited AI Scans & Inference"),
                  const SizedBox(height: 16),
                  _buildFeatureRow(Icons.history_toggle_off, "Full 5-Year Biological Trajectories"),
                  const SizedBox(height: 16),
                  _buildFeatureRow(Icons.picture_as_pdf, "One-tap AI Vet Export Generation"),
                  
                  const Spacer(flex: 2),
                  
                  // Subscribe Button
                  InkWell(
                    onTap: () {
                      // Note: Connect RevenueCat or Stripe here
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Gateway Initializing...')));
                    },
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: Center(
                        child: Text('SUBSCRIBE - \$12.99 / MO', style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text("Restore Purchases", style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.cyanAccent, size: 20),
        ),
        const SizedBox(width: 16),
        Text(text, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
