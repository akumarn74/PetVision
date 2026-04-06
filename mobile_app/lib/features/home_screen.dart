import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_client.dart';
import '../domain/models.dart';
import 'add_pet_screen.dart';
import 'camera_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final petsAsyncValue = ref.watch(petsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Minimalist off-white
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back,', style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                      Text('Your Pets', style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -1)),
                    ],
                  ),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.black,
                    child: const Icon(Icons.person, color: Colors.white),
                  )
                ],
              ),
            ),
            
            // List Feed
            Expanded(
              child: petsAsyncValue.when(
                data: (pets) {
                  if (pets.isEmpty) {
                    return Center(
                      child: Text("No records yet.\nAdd a pet to start tracking.", textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 16, height: 1.5)),
                    );
                  }
                  return RefreshIndicator(
                    color: Colors.black,
                    onRefresh: () async => ref.refresh(petsListProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: pets.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 20),
                      itemBuilder: (context, index) => ModernPetCard(pet: pets[index]),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
                error: (error, stack) => Center(child: Text("Connection Failed.", style: GoogleFonts.plusJakartaSans(color: Colors.redAccent))),
              ),
            ),
          ],
        ),
      ),
      // Massive Pill FAB
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPetScreen())),
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Colors.white),
                const SizedBox(width: 8),
                Text('Add New Pet', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ModernPetCard extends StatelessWidget {
  final PetProfile pet;
  const ModernPetCard({super.key, required this.pet});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TimelineScreen(pet: pet))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32), // Massive squarcle
          border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(child: Text('🐶', style: TextStyle(fontSize: 32))),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pet.name, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: -0.5)),
                      const SizedBox(height: 4),
                      Text('${pet.breed} • ${pet.ageMonths}mo', style: GoogleFonts.plusJakartaSans(fontSize: 15, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 32),
              ],
            ),
            const SizedBox(height: 24),
            // Scanner Action Button
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(pet: pet))),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // Soft premium blue
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Text("START SCAN", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF2563EB), fontWeight: FontWeight.w800, letterSpacing: 1.0, fontSize: 14)),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
