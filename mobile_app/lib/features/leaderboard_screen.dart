import 'dart:ui';
import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xFFF4F6F8), // Deep premium off-white
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Dynamic Header
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFF4F6F8),
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              title: Text(
                "Global Rankings",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 24),
              ),
              background: Stack(
                children: [
                  Positioned(
                    top: -50, right: -50,
                    child: Container(
                      width: 150, height: 150,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.amber.shade200.withValues(alpha: 0.5)),
                    ),
                  ),
                  Positioned(
                     top: 40, left: -20,
                     child: Container(
                         width: 100, height: 100,
                         decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purpleAccent.withValues(alpha: 0.1)),
                     )
                  )
                ],
              ),
            ),
          ),
          
          leaderboardAsync.when(
            data: (pets) {
              if (pets.isEmpty) {
                 return SliverFillRemaining(child: Center(child: Text("No entries yet. Be the first to log nutrition!", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black54))));
              }
              final top3 = pets.take(3).toList();
              final theRest = pets.skip(3).toList();

              return SliverToBoxAdapter(
                 child: Column(
                    children: [
                       if (top3.isNotEmpty) _buildStunningPodium(context, top3),
                       const SizedBox(height: 24),
                       // Rankings Sheet
                       Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                             boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 30, offset: Offset(0, -10))]
                          ),
                          child: Column(
                             crossAxisAlignment: CrossAxisAlignment.stretch,
                             children: [
                                Text("All Challengers", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                                const SizedBox(height: 24),
                                ...theRest.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  PetProfile pet = entry.value;
                                  return _buildPremiumTile(context, pet, index + 4);
                                })
                             ],
                          ),
                       )
                    ],
                 ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Colors.black))),
            error: (err, stack) => SliverFillRemaining(child: Center(child: Text("Error syncing data: $err"))),
          )
        ],
      )
    );
  }

  Widget _buildStunningPodium(BuildContext context, List<PetProfile> top3) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
           if (top3.length > 1) Expanded(child: _buildPillar(context: context, pet: top3[1], rank: 2, height: 160, colors: [Colors.grey.shade300, Colors.grey.shade400], crown: "🥈")),
           if (top3.isNotEmpty) Expanded(child: _buildPillar(context: context, pet: top3[0], rank: 1, height: 210, colors: [const Color(0xFFFFD700), const Color(0xFFFFA500)], crown: "👑")),
           if (top3.length > 2) Expanded(child: _buildPillar(context: context, pet: top3[2], rank: 3, height: 130, colors: [Colors.brown.shade300, Colors.brown.shade500], crown: "🥉")),
        ],
      ),
    );
  }

  Widget _buildPillar({required BuildContext context, required PetProfile pet, required int rank, required double height, required List<Color> colors, required String crown}) {
    final isFirst = rank == 1;
    return Column(
      children: [
        Text(crown, style: TextStyle(fontSize: isFirst ? 40 : 28)),
        const SizedBox(height: 8),
        Container(
           padding: const EdgeInsets.all(4),
           decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8))]
           ),
           child: CircleAvatar(
              radius: isFirst ? 42 : 34,
              backgroundColor: Colors.white,
              child: const Text('🐶', style: TextStyle(fontSize: 32)),
           ),
        ),
        const SizedBox(height: 16),
        Text(pet.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: isFirst ? 18 : 15, color: Colors.black)),
        Text('${pet.xpPoints} XP', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colors.last, fontSize: 13)),
        const SizedBox(height: 12),
        // Glassmorphic Pillar
        Container(
           margin: const EdgeInsets.symmetric(horizontal: 12),
           height: height,
           width: double.infinity,
           decoration: BoxDecoration(
              gradient: LinearGradient(
                 begin: Alignment.topCenter, end: Alignment.bottomCenter,
                 colors: [
                    colors.first.withValues(alpha: 0.9),
                    colors.last.withValues(alpha: 0.7),
                 ]
              ),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, -5))]
           ),
           child: Center(
              child: Text(rank.toString(), style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: isFirst ? 36 : 28, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.4)))
           ),
        )
      ],
    );
  }

  Widget _buildPremiumTile(BuildContext context, PetProfile pet, int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          Text('#$rank', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.grey.shade400)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black)),
                Text(pet.breed, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            )
          ),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
             decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFE8C00), Color(0xFFF83600)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0xFFFE8C00), blurRadius: 10, offset: Offset(0, 4))]
             ),
             child: Text('${pet.xpPoints} XP', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
          )
        ],
      )
    );
  }
}
