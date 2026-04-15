import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/models.dart';
import '../core/api_client.dart';
import 'nutrition_screen.dart';
import 'camera_screen.dart';
import 'nutrition_onboarding_screen.dart';
import 'timeline_screen.dart';
import 'leaderboard_screen.dart';
import 'household_setup_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _fetchStreak();
  }

  Future<void> _fetchStreak() async {
    try {
      final streak = await ref.read(apiClientProvider).getStreak();
      if (mounted) setState(() => _streak = streak);
    } catch (e) {
      // ignore silently if it fails on load
    }
  }

  @override
  Widget build(BuildContext context) {
    final petsAsyncValue = ref.watch(petsListProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Header (Light)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PetVision AI', style: Theme.of(context).textTheme.displayLarge),
                      const SizedBox(height: 4),
                      Text('Dashboard', style: Theme.of(context).textTheme.labelLarge),
                    ],
                  ),
                  Row(
                    children: [
                      // Streak Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
                        child: Row(
                          children: [
                            const Text("🔥", style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text("$_streak", style: GoogleFonts.plusJakartaSans(color: Colors.orange.shade800, fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Leaderboard
                      InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(color: Colors.amber.shade400, shape: BoxShape.circle),
                          child: const Center(child: Text("🏆", style: TextStyle(fontSize: 20))),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // Feed
            Expanded(
              child: petsAsyncValue.when(
                data: (pets) {
                  return RefreshIndicator(
                    color: Colors.black, backgroundColor: Colors.white,
                    onRefresh: () async => ref.refresh(petsListProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: pets.length + 1, // +1 for the Add New Pet card
                      separatorBuilder: (_, __) => const SizedBox(height: 24),
                      itemBuilder: (context, index) {
                        if (index == pets.length) {
                           return GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HouseholdSetupScreen())),
                              child: Container(
                                 height: 100,
                                 decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))]
                                 ),
                                 child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                       const Icon(Icons.add_circle, color: Colors.blueAccent, size: 28),
                                       const SizedBox(width: 12),
                                       Text("Add Pet Profile", style: GoogleFonts.plusJakartaSans(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                                    ],
                                 ),
                              ),
                           );
                        }
                        return CleanPetHeroCard(pet: pets[index]);
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
                error: (error, stack) => Center(child: Text("Connection Failed.", style: GoogleFonts.plusJakartaSans(color: Colors.black54))),
              ),
            ),
          ],
        ),
      )
    );
  }
}

class CleanPetHeroCard extends StatelessWidget {
  final PetProfile pet;
  const CleanPetHeroCard({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TimelineScreen(pet: pet))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 10))],
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5)
        ),
        child: Column(
          children: [
            // Internal Header Layer
            Padding(
               padding: const EdgeInsets.all(24.0),
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
                              child: const Center(child: Text("🐕", style: TextStyle(fontSize: 32)))
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                              child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                    const SizedBox(height: 4),
                                    Text(pet.name, style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1)),
                                    const SizedBox(height: 2),
                                    Text('${pet.breed} • ${pet.ageMonths}mo', style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                 ],
                              )
                           ),
                           // Level / Badge
                           Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text("${pet.xpPoints} XP", style: GoogleFonts.plusJakartaSans(color: Colors.amber.shade900, fontWeight: FontWeight.w900, fontSize: 13)),
                           )
                        ],
                     ),
                     if (pet.joinCode != null) ...[
                        const SizedBox(height: 20),
                        InkWell(
                          onTap: () {
                             Clipboard.setData(ClipboardData(text: pet.joinCode!));
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invite Code copied!"), backgroundColor: Colors.green));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                  Icon(Icons.family_restroom, size: 14, color: Colors.blue.shade600),
                                  const SizedBox(width: 8),
                                  Text("Invite Code: ${pet.joinCode}", style: GoogleFonts.plusJakartaSans(color: Colors.blue.shade600, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                               ],
                            )
                          ),
                        )
                     ]
                  ],
               ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                 color: const Color(0xFFF8FAFC), // Slight offset from white
                 borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
                 border: Border(top: BorderSide(color: Colors.grey.shade100))
              ),
              child: Row(
                children: [
                  // Button 1: LOG DIET
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (pet.targetCalories == null) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => NutritionOnboardingScreen(pet: pet)));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => NutritionScreen(pet: pet)));
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.restaurant_menu_rounded, color: Colors.green, size: 18),
                            const SizedBox(width: 8),
                            Text("LOG DIET", style: GoogleFonts.plusJakartaSans(color: Colors.green.shade700, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Button 2: SNAP SCAT
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(pet: pet))),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text("SCAN", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
