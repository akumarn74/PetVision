import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../domain/models.dart';

final leaderboardProvider = FutureProvider.autoDispose<List<PetProfile>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return await client.getLeaderboard();
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Off-white luxury background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text("Global Rankings", style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
      ),
      body: leaderboardAsync.when(
        data: (pets) {
          if (pets.isEmpty) {
             return const Center(child: Text("No data. Be the first!"));
          }
          final top3 = pets.take(3).toList();
          final theRest = pets.skip(3).toList();

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildPodium(top3)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final pet = theRest[index];
                      // Rank is index + 3 + 1
                      return _buildLeaderboardTile(pet, index + 4);
                    },
                    childCount: theRest.length,
                  )
                ),
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.black)),
        error: (err, stack) => Center(child: Text("Failed to load rankings: $err")),
      )
    );
  }

  Widget _buildPodium(List<PetProfile> top3) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
           if (top3.length > 1) _buildPodiumColumn(top3[1], 2, Colors.grey.shade400, 140),
           if (top3.isNotEmpty) _buildPodiumColumn(top3[0], 1, Colors.amber.shade400, 180),
           if (top3.length > 2) _buildPodiumColumn(top3[2], 3, Colors.brown.shade300, 110),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn(PetProfile pet, int rank, Color crownColor, double height) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: crownColor.withValues(alpha: 0.2),
              child: const Text('🐶', style: TextStyle(fontSize: 32)),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: crownColor, shape: BoxShape.circle),
              child: Text('$rank', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ]
        ),
        const SizedBox(height: 12),
        Text(pet.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
        Text('${pet.xpPoints} XP', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: crownColor, fontSize: 14)),
        const SizedBox(height: 12),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            boxShadow: [BoxShadow(color: crownColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5))]
          ),
        )
      ],
    );
  }

  Widget _buildLeaderboardTile(PetProfile pet, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]
      ),
      child: Row(
        children: [
          Container(
             width: 40, height: 40,
             decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
             child: Center(child: Text('#$rank', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                Text(pet.breed, style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade500, fontSize: 13)),
              ],
            )
          ),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16)
             ),
             child: Text('${pet.xpPoints} XP', style: GoogleFonts.plusJakartaSans(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }
}
