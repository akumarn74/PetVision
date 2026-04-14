import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/models.dart';
import '../core/api_client.dart';
import 'paywall_screen.dart';
import 'dart:ui';

class NutritionScreen extends ConsumerStatefulWidget {
  final PetProfile pet;
  const NutritionScreen({super.key, required this.pet});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends ConsumerState<NutritionScreen> {
  bool _isLogging = false;
  late Future<Map<String, dynamic>> _nutritionFuture;

  // Search Typeahead State
  final TextEditingController _searchController = TextEditingController();
  List<FoodCatalogItem> _searchResults = [];
  Timer? _debounce;
  bool _isSearching = false;

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
  
  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (query.isEmpty) {
        setState(() => _searchResults = []);
        return;
      }
      setState(() => _isSearching = true);
      try {
        final results = await ref.read(apiClientProvider).searchPredefinedFoods(query);
        if (mounted) setState(() => _searchResults = results);
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _triggerSuccessLottie() async {
    showDialog(
       context: context,
       barrierDismissible: false,
       barrierColor: Colors.white.withValues(alpha: 0.8),
       builder: (ctx) => Center(
         child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
               return Transform.scale(
                  scale: value,
                  child: Container(
                     padding: const EdgeInsets.all(24),
                     decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))]),
                     child: Icon(Icons.check_circle_rounded, color: Colors.green.shade500, size: 80),
                  )
               );
            }
         )
       )
    );
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.pop(context);
    _refreshDashboard();
  }


  Future<void> _logPredefinedMeal(String foodId) async {
    Navigator.pop(context); // close modal
    setState(() => _isLogging = true);
    try {
      await ref.read(apiClientProvider).logPredefinedFood(widget.pet.id, foodId);
      await _triggerSuccessLottie();
    } catch(e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  Future<void> _logTextMeal(String text) async {
    Navigator.pop(context);
    setState(() => _isLogging = true);
    try {
      await ref.read(apiClientProvider).logDietMeal(widget.pet.id, text);
      await _triggerSuccessLottie();
    } catch(e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  Future<void> _snapMeal() async {
    Navigator.pop(context);
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo == null) return;
    
    setState(() => _isLogging = true);
    try {
      final bytes = await photo.readAsBytes();
      final base64Image = base64Encode(bytes);
      await ref.read(apiClientProvider).logDietImage(widget.pet.id, base64Image);
      await _triggerSuccessLottie();
    } catch(e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  void _handleError(Object e) {
      if (!mounted) return;
      if (e.toString().contains("402")) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => const PaywallScreen()
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
  }

  void _showLoggingModal() {
    _searchController.clear();
    _searchResults.clear();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            void onModalSearch(String val) {
                if (_debounce?.isActive ?? false) _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () async {
                  if (val.isEmpty) {
                    setModalState(() => _searchResults = []);
                    return;
                  }
                  setModalState(() => _isSearching = true);
                  try {
                    final results = await ref.read(apiClientProvider).searchPredefinedFoods(val);
                    if (mounted) setModalState(() => _searchResults = results);
                  } finally {
                    if (mounted) setModalState(() => _isSearching = false);
                  }
                });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              ),
              child: Column(
                children: [
                   const SizedBox(height: 12),
                   Container(width: 40, height: 6, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                   const SizedBox(height: 24),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24.0),
                     child: TextField(
                        controller: _searchController,
                        onChanged: onModalSearch,
                        style: GoogleFonts.plusJakartaSans(fontSize: 18),
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: "Search food database...",
                          prefixIcon: const Icon(Icons.search, size: 28),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                        // Fallback NLP Text Logging
                        onSubmitted: (val) {
                          if (val.isNotEmpty) {
                             _logTextMeal(val);
                          }
                        },
                     ),
                   ),
                   const SizedBox(height: 16),
                   
                   // Dynamic Results
                   Expanded(
                     child: _searchController.text.isEmpty
                       ? _buildModalIdleView()
                       : (_isSearching 
                           ? const Center(child: CircularProgressIndicator()) 
                           : _buildModalSearchResults()
                         ),
                   )
                ]
              )
            );
          }
        );
      }
    );
  }

  Widget _buildModalIdleView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        GestureDetector(
          onTap: _snapMeal,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
               gradient: const LinearGradient(colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)]),
               borderRadius: BorderRadius.circular(24),
               boxShadow: [BoxShadow(color: const Color(0xFF1BFFFF).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))]
            ),
            child: Row(
              children: [
                const Icon(Icons.center_focus_strong, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Snap AI Meal", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text("Let GPT-4o Vision calculate macros.", style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                )
              ],
            )
          ),
        ),
        const SizedBox(height: 24),
        Text("Popular Foods", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        FutureBuilder<List<FoodCatalogItem>>(
          future: ref.read(apiClientProvider).searchPredefinedFoods(""),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
               return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
               return Center(child: Text("Or type a custom meal description to use standard NLP.", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 13)));
            }
            final popularFoods = snapshot.data!.take(5).toList();
            return Column(
              children: popularFoods.map((food) => ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: CircleAvatar(backgroundColor: Colors.grey.shade100, child: const Icon(Icons.star, color: Colors.amber)),
                title: Text(food.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                subtitle: Text("${food.brand} • ${food.servingSizeDesc}", style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black54)),
                trailing: Text("${food.caloriesPerServing} kcal", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: Colors.orange.shade700)),
                onTap: () => _logPredefinedMeal(food.id),
              )).toList(),
            );
          }
        )
      ],
    );
  }

  Widget _buildModalSearchResults() {
    if (_searchResults.isEmpty) {
        return Center(child: Text("No exact matches. Hit 'Enter' to use AI Text Parser.", style: GoogleFonts.plusJakartaSans(color: Colors.black54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) {
         final food = _searchResults[i];
         return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            leading: CircleAvatar(backgroundColor: Colors.grey.shade100, child: const Icon(Icons.fastfood, color: Colors.black54)),
            title: Text(food.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            subtitle: Text("${food.brand} • ${food.servingSizeDesc}", style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.black54)),
            trailing: Text("${food.caloriesPerServing} kcal", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: Colors.green)),
            onTap: () => _logPredefinedMeal(food.id),
         );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Apple UI off-white
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.pet.name}\'s Nutrition', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        flexibleSpace: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent))),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5, offset: const Offset(0, 10))]
        ),
        child: FloatingActionButton.extended(
          onPressed: _isLogging ? null : _showLoggingModal,
          backgroundColor: Colors.white,
          elevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          highlightElevation: 0,
          icon: _isLogging ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color:Colors.black)) : const Icon(Icons.add_rounded, color: Colors.black, size: 28),
          label: Text("LOG MEAL", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black)),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _nutritionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator(color: Colors.black));
          }
          if (snapshot.hasError) {
             return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }
          
          final data = snapshot.data!;
          final todayKcal = data["today_calories"] ?? 0.0;
          final targetKcal = data["target_calories"] ?? 1000.0;
          final recommendation = data["ai_recommendation"] ?? "Tracking active.";
          final List recentMeals = data["recent_meals"] ?? [];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: const SizedBox(height: 120)), // Below App Bar
              
              // MASSIVE CALORIE DIAL
              SliverToBoxAdapter(
                 child: Center(
                   child: Container(
                     width: 260, height: 260,
                     decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.1), blurRadius: 40, spreadRadius: 10),
                          const BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
                        ]
                     ),
                     child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 220, height: 220,
                            child: CircularProgressIndicator(
                              value: (todayKcal / targetKcal).clamp(0.0, 1.0),
                              strokeWidth: 20,
                              backgroundColor: const Color(0xFFF1F5F9),
                              color: todayKcal > targetKcal ? const Color(0xFFFF4757) : const Color(0xFF2ED573),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(todayKcal.toStringAsFixed(0), style: GoogleFonts.plusJakartaSans(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -3)),
                              Text("KCAL EATEN", style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade500, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
                                child: Text('REMAINING: ${(targetKcal - todayKcal > 0 ? targetKcal - todayKcal : 0).toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              )
                            ],
                          )
                        ],
                     ),
                   )
                 )
              ),
              
              // GPT-4o Insights Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                       gradient: LinearGradient(colors: [Colors.greenAccent.shade100.withValues(alpha: 0.3), Colors.white]),
                       borderRadius: BorderRadius.circular(32),
                       border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5), width: 1.5),
                       boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.05), blurRadius: 20)]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                           children: [
                             const Icon(Icons.auto_awesome, color: Colors.green, size: 20),
                             const SizedBox(width: 8),
                             Text("AI Recommendation", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: Colors.green.shade800)),
                           ],
                        ),
                        const SizedBox(height: 12),
                        Text(recommendation, style: GoogleFonts.plusJakartaSans(height: 1.5, fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),

              // RECENT MEALS SLIVER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text("Log History", style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),

              if (recentMeals.isEmpty)
                 SliverToBoxAdapter(
                    child: Padding(
                       padding: const EdgeInsets.all(40),
                       child: Center(child: Text("No meals logged today. Time to eat!", style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 16))),
                    )
                 )
              else
                 SliverPadding(
                   padding: const EdgeInsets.all(24).copyWith(bottom: 100), // padding for FAB
                   sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                           final m = recentMeals[index];
                           return Dismissible(
                             key: Key(m["id"] ?? index.toString()),
                             direction: DismissDirection.endToStart,
                             background: Container(
                               margin: const EdgeInsets.only(bottom: 16),
                               padding: const EdgeInsets.symmetric(horizontal: 24),
                               decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                               alignment: Alignment.centerRight,
                               child: const Icon(Icons.delete_sweep, color: Colors.white, size: 28),
                             ),
                             onDismissed: (_) async {
                               try {
                                  await ref.read(apiClientProvider).deleteDietEntry(m["id"]);
                                  _refreshDashboard();
                               } catch(e) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete entry')));
                               }
                             },
                             child: Container(
                                 margin: const EdgeInsets.only(bottom: 16),
                                 padding: const EdgeInsets.all(16),
                                 decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]
                                 ),
                                 child: Row(
                                    children: [
                                       Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                                          child: const Icon(Icons.fastfood, color: Colors.black),
                                       ),
                                       const SizedBox(width: 16),
                                       Expanded(
                                          child: Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                                Text(m["food_name"], style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                const SizedBox(height: 4),
                                                Text("Protein: ${m["proteins_g"]}g  |  Fats: ${m["fats_g"]}g", style: GoogleFonts.plusJakartaSans(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                             ],
                                          )
                                       ),
                                       Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
                                          child: Text('${m['calories']} kcal', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                       )
                                    ],
                                 ),
                             ),
                           );
                        },
                        childCount: recentMeals.length,
                      ),
                   )
                 )
            ]
          );
        }
      )
    );
  }
}
