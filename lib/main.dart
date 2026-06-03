import 'dart:convert';
import 'dart:async';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_symbols_icons/symbols_map.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CarTripApp());
}

class CarTripApp extends StatelessWidget {
  const CarTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Trip',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const CategoryScreen(),
    );
  }
}

class TripItem {
  final String category;
  final String subCategory;
  final String name;
  final String itemId;
  final String iconName; // from CSV Icon column
  final int points; // from CSV Points column
  final List<String> achievementIds;

  TripItem({
    required this.category,
    required this.subCategory,
    required this.name,
    required this.itemId,
    required this.iconName,
    required this.points,
    required this.achievementIds,
  });
}

class Trip {
  final String tripId;
  final String tripName;
  final String startLocation;
  final String endLocation;

  final int score;
  final int maxScore;
  final double percent;

  final int itemsFound;
  final int maxItemsFound;

  final int subCategoriesCompleted;
  final int categoriesCompleted;
  final int finalRankIndex;

  final int totalCategories;
  final int totalSubCategories;

  final int doubleItemsFound;
  final int totalDoubleItems;
  final int doubleScore;
  final int doubleMaxScore;

  final int tripleItemsFound;
  final int totalTripleItems;
  final int tripleScore;
  final int tripleMaxScore;

  final int oneScore;
  final int oneMaxScore;

  final int twoScore;
  final int twoMaxScore;

  final int threeScore;
  final int threeMaxScore;

  final int fourScore;
  final int fourMaxScore;

  final List<String> completedAchievementIds;
  final Set<String> newAchievementIds;
  final Map<String, int> achievementTotals;
  final Map<String, int> achievementFoundCounts;

  final bool perfectRun;

  final DateTime startTime;
  final DateTime endTime;

  Trip({
    required this.tripId,
    required this.tripName,
    required this.startLocation,
    required this.endLocation,
    required this.score,
    required this.maxScore,
    required this.percent,
    required this.itemsFound,
    required this.maxItemsFound,
    required this.subCategoriesCompleted,
    required this.categoriesCompleted,
    required this.totalCategories,
    required this.totalSubCategories,
    required this.finalRankIndex,
    required this.perfectRun,
    required this.startTime,
    required this.endTime,
    required this.doubleItemsFound,
    required this.totalDoubleItems,
    required this.doubleScore,
    required this.doubleMaxScore,
    required this.tripleItemsFound,
    required this.totalTripleItems,
    required this.tripleScore,
    required this.tripleMaxScore,

    required this.oneScore,
    required this.oneMaxScore,

    required this.twoScore,
    required this.twoMaxScore,

    required this.threeScore,
    required this.threeMaxScore,

    required this.fourScore,
    required this.fourMaxScore,

    required this.completedAchievementIds,
    required this.newAchievementIds,
    required this.achievementTotals,
    required this.achievementFoundCounts,
  });
  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'tripName': tripName,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'score': score,
      'maxScore': maxScore,
      'percent': percent,
      'itemsFound': itemsFound,
      'maxItemsFound': maxItemsFound,
      'subCategoriesCompleted': subCategoriesCompleted,
      'categoriesCompleted': categoriesCompleted,
      'finalRankIndex': finalRankIndex,
      'totalCategories': totalCategories,
      'totalSubCategories': totalSubCategories,
      'doubleItemsFound': doubleItemsFound,
      'totalDoubleItems': totalDoubleItems,
      'doubleScore': doubleScore,
      'doubleMaxScore': doubleMaxScore,
      'tripleItemsFound': tripleItemsFound,
      'totalTripleItems': totalTripleItems,
      'tripleScore': tripleScore,
      'tripleMaxScore': tripleMaxScore,
      'oneScore': oneScore,
      'oneMaxScore': oneMaxScore,
      'twoScore': twoScore,
      'twoMaxScore': twoMaxScore,
      'threeScore': threeScore,
      'threeMaxScore': threeMaxScore,
      'fourScore': fourScore,
      'fourMaxScore': fourMaxScore,
      'completedAchievementIds': completedAchievementIds,
      'newAchievementIds': newAchievementIds.toList(),
      'achievementTotals': achievementTotals,
      'achievementFoundCounts': achievementFoundCounts,
      'perfectRun': perfectRun,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
    };
  }
}

class GroupStat {
  final String name;
  final int found;
  final int total;
  final int score;
  final int maxScore;
  final String iconName;

  GroupStat({
    required this.name,
    required this.found,
    required this.total,
    required this.score,
    required this.maxScore,
    required this.iconName,
  });

  double get progress => total == 0 ? 0.0 : found / total;
  int get remainingCount => total - found;
  int get scoreRemaining => maxScore - score;
  bool get complete => total != 0 && found == total;
}

enum SortMode {
  az,
  leastItemsLeft,
  mostItemsLeft,
  leastPointsLeft,
  mostPointsLeft,
}

// Sound priorities (higher number = more important)
const int SFX_SUB = 1;
const int SFX_CATEGORY = 2;
const int SFX_RANK = 3;
const int SFX_DOUBLE = 4;
const int SFX_POINTER = 5;
const int SFX_ACHIEVEMENT = 6;
const int SFX_WIN = 7;
const int SFX_PERFECT = 8;
const List<String> kRanks = [
  '😞 0: Noob',
  '👎 1: Inept',
  '😴 2: Cringe',
  '😐 3: Mega-Mid',
  '👌 4: Mid',
  '👍 5: Decent',
  '✨ 6: Slay',
  '💥 7: Mad-Lit',
  '🔥 8: Fire',
  '🦁 9: Apex',
  '🐐 10: GOAT',
];

Color rankColor(int idx) {
  const colors = <Color>[
    Color(0xFFE0E0E0),
    Color(0xFF64B5F6),
    Color(0xFF4CAF50),
    Color(0xFFFBC02D),
    Color(0xFFFB8C00),
    Color(0xFFE57373),
    Color(0xFFE53935),
    Color(0xFF5E35B1),
    Color(0xFF2C3E50),
    Color(0xFF000000),
    Color(0xFFD4AF37),
  ];
  return colors[idx.clamp(0, colors.length - 1)];
}

const Map<String, String> achievementLabels = {
  'flying': 'Air today gone tomorrow!',
  'animals': 'Animals crackers!',
  'farmer': 'Me and the farmer!',
  'builder': 'Bob the builder!',
  'location': 'Location location location!',
  'rainbow': 'Somewhere over the rainbow!',
  'interest': 'Been there done that!',
  'fuel': 'Fuel the imagination!',
  'rule': 'Rule Britannia!',
  'pub': 'Cheers!',
  'shop_drop': "Shop 'til you drop!",
  'bike': 'On yer bike!',
  'poppy': 'Lest we forget!',
  'park_mate': "You can't park there mate!",
  'top_gear': 'Top Gear!',
  'plate': 'Put it on a plate!',
  'learning': 'Learning the hard way!',
  'bin': "It's bin a long time coming!",
  'bus_coach': 'Bus-ted!',
  'object': 'Object of desire!',
  'wavelength': "We're on the same wavelength!",
  'naturel': 'Au naturel!',
  'middle_road': 'Middle of the road!',
  'speed_freak': 'Speed freak!',
  'cone_head': 'Cone head!',
  'distance': 'Long distance runner!',
  'highway': 'Highway robbery!',
  'orange_black': 'Orange is the new black!',
  'stand_deliver': 'Stand and deliver!',
  'long_haul': 'In it for the long haul!',
  'vans_man': 'A vans man!',
  'retail_therapy': 'Retail therapy!',
  'little_help': 'Every little helps!',
  'blues_twos': 'Blues and twos!',
  'bread': 'Bread and butter!',
};

const Map<int, String> pointerTierLabels = {
  1: 'One and done!',
  2: 'Double trouble!',
  3: 'Triple threat!',
  4: 'Four-midable!',
};

String sortLabel(SortMode mode) {
  switch (mode) {
    case SortMode.az:
      return 'A-Z';
    case SortMode.leastItemsLeft:
      return 'Fewest Items Left';
    case SortMode.mostItemsLeft:
      return 'Most Items Left';
    case SortMode.leastPointsLeft:
      return 'Fewest Points Left';
    case SortMode.mostPointsLeft:
      return 'Most Points Left';
  }
}

String _norm(String s) =>
    s.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

Color _progressColor(double p) {
  if (p == 0) return Colors.grey;
  if (p < 0.20) return Color(0xFFB71C1C);
  if (p < 0.40) return Colors.orange;
  if (p < 0.60) return Colors.deepOrangeAccent;
  if (p < 0.80) return Colors.yellow.shade700;
  if (p < 1.0) return Colors.lightGreen;
  return Color(0xFF1B5E20);
}

/// Weekdays + Saturday: >= 90.0%
/// Sunday: >= 80.0%
double winningThresholdPercent(DateTime now) {
  return (now.weekday == DateTime.sunday) ? 80.0 : 90.0;
}

String dayName(DateTime now) {
  switch (now.weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    case DateTime.sunday:
      return 'Sun';
    default:
      return '';
  }
}

/// Resolve Material Symbols icon:
/// 1) CSV Icon string -> materialSymbolsMap
/// 2) Group name -> materialSymbolsMap
/// 3) Overrides for common buckets
/// 4) fallback Symbols.help
IconData resolveIcon({required String iconName, required String groupName}) {
  final iconKey = _norm(iconName);
  final groupKey = _norm(groupName);

  // ✅ Force override for car category before map lookup
  if (groupKey == 'car' || groupKey.contains('cars')) {
    return Symbols.directions_car;
  }

  final direct = materialSymbolsMap[iconKey];
  if (direct != null) return direct;

  final fromGroup = materialSymbolsMap[groupKey];
  if (fromGroup != null) return fromGroup;

  final overrideKey = _overrideIconKey(groupKey);
  final overridden = materialSymbolsMap[overrideKey];
  if (overridden != null) return overridden;

  return Symbols.help;
}

String _overrideIconKey(String groupKey) {
  if (groupKey.contains('building')) return 'location_city';
  if (groupKey == 'car' || groupKey.contains('cars')) return 'directions_car';
  if (groupKey.contains('motorcycle')) return 'motorcycle';
  if (groupKey.contains('playground')) return 'playground';
  if (groupKey.contains('road')) return 'alt_route';
  if (groupKey.contains('misc') || groupKey.contains('item')) return 'category';
  return 'category';
}

/* -------------------------
   CATEGORY SCREEN
-------------------------- */

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  static const prefsKey = 'found_map';
  static const achievementsKey = 'all_time_achievements';
  static const csvPath = 'assets/Car Trip List App Latest Version.csv';

  List<TripItem> items = [];
  Map<String, bool> foundById = {};
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _hapticsEnabled = true;
  bool _soundEnabled = true;

  Map<String, bool>? _previousFoundById;
  Set<String>? _previousCompletedCategoriesShown;
  Set<String>? _previousCompletedAchievements;
  Set<int>? _previousCompletedPointerTiers;
  List<GroupStat> categoryStats = [];

  int totalScore = 0;

  int maxScore = 0;

  bool loading = true;
  bool _isRestoringState = false;
  String? error;

  SortMode sortMode = SortMode.az;

  // prevent repeating category-complete dialog
  Set<String> _completedCategoriesShown = {};
  Set<String> _completedSubcategoriesShownGlobal = {};
  Set<String>? _previousCompletedSubcategoriesShownGlobal;

  // --- Trip session state ---
  String? _currentTripType;
  String? _currentStartLocation;
  String? _currentEndLocation;
  DateTime? _tripStartTime;
  String? _currentSessionId;
  Set<String> _bonusItemIds = {};
  Set<String> _tripleItemIds = {};
  Set<String> _completedAchievements = {};
  Set<String> _allTimeAchievements = {};
  Set<String> _sessionUnlockedAchievements = {};
  Timer? _sessionPollingTimer;
  Set<int> _completedPointerTiers = {};
  Map<String, Set<String>> _achievementItemIds = {};

  bool _gameCompletedShown = false;
  bool _perfectRunShown = false;
  int _lastRankIndex = -1;
  Trip? _lastCompletedTrip;

  // Tracks the priority of the sound currently allowed to play
  int _activeSfxPriority = 0;

  @override
  void initState() {
    super.initState();

    _loadAll();
  }

  @override
  void dispose() {
    _sessionPollingTimer?.cancel();
    _sfxPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
      _isRestoringState = true;
    });

    try {
      // Based on your CSV header layout:
      // Category,Sub-Category,Item Name,Points,Found,Item ID,...,Icon,...
      const cCategory = 0;
      const cSub = 1;
      const cName = 2;
      const cPoints = 3;
      const cItemId = 5;
      const cIcon = 7;
      const cAchievementIds = 8;

      final raw = await rootBundle.loadString(csvPath);

      // ✅ confirmed working approach on your machine
      final rows = csv.decode(raw);

      final parsed = <TripItem>[];
      final freshFound = <String, bool>{};

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= cIcon) continue;

        final category = row[cCategory].toString().trim();
        final sub = row[cSub].toString().trim();
        final name = row[cName].toString().trim();
        final points = int.tryParse(row[cPoints].toString().trim()) ?? 1;
        final itemId = row[cItemId].toString().trim();
        final iconName = row[cIcon].toString().trim();
        final rawAchievementIds = row.length > cAchievementIds
            ? row[cAchievementIds].toString().trim()
            : '';
        final achievementIds = rawAchievementIds.isEmpty
            ? <String>[]
            : rawAchievementIds
                  .split('|')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();

        if (category.isEmpty || sub.isEmpty || name.isEmpty || itemId.isEmpty) {
          continue;
        }

        parsed.add(
          TripItem(
            category: category,
            subCategory: sub,
            name: name,
            itemId: itemId,
            iconName: iconName,
            points: points,
            achievementIds: achievementIds,
          ),
        );

        freshFound[itemId] = false;
      }

      final prefs = await SharedPreferences.getInstance();
      _hapticsEnabled = prefs.getBool('haptics_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      final saved = prefs.getString(prefsKey);
      if (saved != null && saved.trim().isNotEmpty) {
        final map = jsonDecode(saved) as Map<String, dynamic>;
        map.forEach((k, v) {
          if (freshFound.containsKey(k)) {
            freshFound[k] = v == true;
          }
        });
      }
      final savedAchievements = prefs.getStringList(achievementsKey);
      if (savedAchievements != null) {
        _allTimeAchievements = savedAchievements.toSet();
      }
      items = parsed;
      foundById = freshFound;

      _recomputeCategoryStats();

      setState(() {
        loading = false;
        _isRestoringState = false;
      });

      // ✅ Do NOT trigger celebration after restore
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void _startSessionPolling() {
    _sessionPollingTimer?.cancel();

    _sessionPollingTimer = Timer.periodic(const Duration(milliseconds: 1400), (
      _,
    ) async {
      if (_currentSessionId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('trip_sessions')
          .doc(_currentSessionId)
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;

      // ✅ Stop if session ended remotely
      if (data['active'] != true) {
        _sessionPollingTimer?.cancel();

        if (!mounted) return;

        setState(() {
          _currentSessionId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session ended'),
            duration: Duration(milliseconds: 1200),
          ),
        );

        return;
      }

      final remoteFoundItems = Map<String, dynamic>.from(
        data['foundItems'] ?? {},
      );

      bool changed = false;

      for (final key in remoteFoundItems.keys) {
        final remoteValue = remoteFoundItems[key] == true;
        if (foundById[key] != remoteValue) {
          foundById[key] = remoteValue;
          changed = true;
        }
      }

      if (changed) {
        setState(() {
          _recomputeCategoryStats();
        });
      }
    });
  }

  double _getTargetPercent() {
    return winningThresholdPercent(DateTime.now());
  }

  String _getDayName() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[DateTime.now().weekday - 1];
  }

  double _getProgressPercent() {
    if (maxScore == 0) return 0;
    return (totalScore / maxScore) * 100;
  }

  String _generateTripId({
    required DateTime date,
    required String start,
    required String end,
  }) {
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');

    final datePart = '$yy$mm$dd';

    String clean(String text) {
      return text
          .trim()
          .toLowerCase()
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    }

    final startClean = clean(start);
    final endClean = clean(end);

    return '${datePart}_${startClean}_${endClean}_${DateTime.now().millisecondsSinceEpoch}';
  }

  int _getRankIndex() {
    final progress = _getProgressPercent();

    if (progress >= 95.0) return 10; // GOAT
    if (progress >= 90.0) return 9; // Apex

    return (progress ~/ 10).clamp(0, 8);
  }

  int _getCompletedSubCategoryCount() {
    final subCategoryMap = <String, List<TripItem>>{};

    // Group items by subcategory
    for (final item in items) {
      subCategoryMap.putIfAbsent(item.subCategory, () => []);
      subCategoryMap[item.subCategory]!.add(item);
    }

    int completed = 0;

    // Count completed subcategories
    for (final entry in subCategoryMap.entries) {
      final allFound = entry.value.every(
        (item) => foundById[item.itemId] == true,
      );

      if (allFound) {
        completed++;
      }
    }

    return completed;
  }

  int _getTotalCategories() {
    return items.map((e) => e.category).toSet().length;
  }

  int _getTotalSubCategories() {
    return items.map((e) => e.subCategory).toSet().length;
  }

  int _getCompletedAchievementCount() {
    return _completedAchievements.length;
  }

  int _getTotalAchievementCount() {
    return achievementLabels.length;
  }

  Set<String> _generateBonusItemIds() {
    final Map<int, List<TripItem>> groupedByPoints = {};

    for (final item in items) {
      groupedByPoints.putIfAbsent(item.points, () => []);
      groupedByPoints[item.points]!.add(item);
    }

    final Set<String> selectedIds = {};

    for (final entry in groupedByPoints.entries) {
      final groupItems = List<TripItem>.from(entry.value);
      final int groupSize = groupItems.length;

      // ✅ DOUBLE is now 9%, still rounded like before
      final int numberToSelect = (groupSize * 0.09).round();

      if (numberToSelect <= 0) {
        continue;
      }

      groupItems.shuffle();

      final chosen = groupItems.take(numberToSelect);
      for (final item in chosen) {
        selectedIds.add(item.itemId);
      }
    }

    return selectedIds;
  }

  Set<String> _generateTripleItemIds(Set<String> excludedIds) {
    final Map<int, List<TripItem>> groupedByPoints = {};

    for (final item in items) {
      // ✅ No item can be both DOUBLE and TRIPLE
      if (excludedIds.contains(item.itemId)) continue;

      groupedByPoints.putIfAbsent(item.points, () => []);
      groupedByPoints[item.points]!.add(item);
    }

    final Set<String> selectedIds = {};

    for (final entry in groupedByPoints.entries) {
      final groupItems = List<TripItem>.from(entry.value);
      final int groupSize = groupItems.length;

      // ✅ TRIPLE is 3%, and small groups can naturally become 0
      final int numberToSelect = (groupSize * 0.03).floor();

      if (numberToSelect <= 0) {
        continue;
      }

      groupItems.shuffle();

      final chosen = groupItems.take(numberToSelect);
      for (final item in chosen) {
        selectedIds.add(item.itemId);
      }
    }

    return selectedIds;
  }

  void _applySort(List<GroupStat> list) {
    switch (sortMode) {
      case SortMode.az:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortMode.leastItemsLeft:
        list.sort((a, b) => a.remainingCount.compareTo(b.remainingCount));
        break;
      case SortMode.mostItemsLeft:
        list.sort((a, b) => b.remainingCount.compareTo(a.remainingCount));
        break;
      case SortMode.leastPointsLeft:
        list.sort((a, b) => a.scoreRemaining.compareTo(b.scoreRemaining));
        break;
      case SortMode.mostPointsLeft:
        list.sort((a, b) => b.scoreRemaining.compareTo(a.scoreRemaining));
        break;
    }
  }

  void _recomputeCategoryStats() {
    final totals = <String, int>{};
    final founds = <String, int>{};
    final scores = <String, int>{};
    final maxScores = <String, int>{};
    final iconCounts = <String, Map<String, int>>{};

    totalScore = 0;
    maxScore = 0;

    // ✅ Build achievement → itemId mapping
    _achievementItemIds.clear();

    for (final it in items) {
      for (final achievementId in it.achievementIds) {
        _achievementItemIds.putIfAbsent(achievementId, () => <String>{});
        _achievementItemIds[achievementId]!.add(it.itemId);
      }
    }

    // ✅ MAIN LOOP — THIS IS THE IMPORTANT PART

    for (final it in items) {
      final isTriple = _tripleItemIds.contains(it.itemId);
      final isDouble = _bonusItemIds.contains(it.itemId);

      final itemMaxPoints = isTriple
          ? it.points * 3
          : isDouble
          ? it.points * 2
          : it.points;

      totals[it.category] = (totals[it.category] ?? 0) + 1;
      maxScores[it.category] = (maxScores[it.category] ?? 0) + itemMaxPoints;
      maxScore += itemMaxPoints;

      iconCounts.putIfAbsent(it.category, () => <String, int>{});
      final m = iconCounts[it.category]!;

      final key = it.iconName.isEmpty ? 'category' : it.iconName;
      m[key] = (m[key] ?? 0) + 1;

      if (foundById[it.itemId] == true) {
        founds[it.category] = (founds[it.category] ?? 0) + 1;
        scores[it.category] = (scores[it.category] ?? 0) + itemMaxPoints;
        totalScore += itemMaxPoints;
      }
    }

    final list = <GroupStat>[];
    for (final cat in totals.keys) {
      final counts = iconCounts[cat] ?? {};
      String chosen = 'category';
      int best = -1;
      counts.forEach((k, v) {
        if (v > best) {
          best = v;
          chosen = k;
        }
      });

      list.add(
        GroupStat(
          name: cat,
          found: founds[cat] ?? 0,
          total: totals[cat] ?? 0,
          score: scores[cat] ?? 0,
          maxScore: maxScores[cat] ?? 0,
          iconName: chosen,
        ),
      );
    }

    // Split into unfinished and completed
    final unfinished = list.where((e) => !e.complete).toList();
    final completed = list.where((e) => e.complete).toList();

    // Sort each group alphabetically
    unfinished.sort((a, b) => a.name.compareTo(b.name));
    completed.sort((a, b) => a.name.compareTo(b.name));

    if (sortMode == SortMode.az) {
      final unfinished = list.where((e) => !e.complete).toList();
      final completed = list.where((e) => e.complete).toList();

      unfinished.sort((a, b) => a.name.compareTo(b.name));
      completed.sort((a, b) => a.name.compareTo(b.name));

      categoryStats = [...unfinished, ...completed];
    } else {
      _applySort(list);
      categoryStats = List.from(list);
    }

    _checkGameCompletion();
    _checkPerfectRun();
    // IMPORTANT: rank check AFTER category celebration
  }

  Future<void> _toggleAndPersist(String id, bool value) async {
    foundById[id] = value;

    // ✅ Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(foundById));

    // ✅ If in multiplayer session, sync to Firestore
    if (_currentSessionId != null) {
      await FirebaseFirestore.instance
          .collection('trip_sessions')
          .doc(_currentSessionId)
          .update({
            'foundItems': foundById,
            'lastUpdated': DateTime.now().toIso8601String(),
          });
    }
  }

  Future<void> _saveTripToFirestore(Trip trip) async {
    await FirebaseFirestore.instance
        .collection('trips')
        .doc(trip.tripId)
        .set(trip.toMap());
  }

  Future<List<Trip>> _loadTripsFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('trips').get();
    final trips = snapshot.docs.map((doc) {
      final data = doc.data();

      int readInt(String key) => (data[key] as num?)?.toInt() ?? 0;
      double readDouble(String key) => (data[key] as num?)?.toDouble() ?? 0.0;
      String readString(String key) => (data[key] ?? '').toString();
      bool readBool(String key) => data[key] == true;

      DateTime readDate(String key) {
        final value = data[key];
        if (value is Timestamp) return value.toDate();
        if (value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
        throw FormatException('Invalid $key in trip ${doc.id}: $value');
      }

      return Trip(
        tripId: readString('tripId'),
        tripName: readString('tripName'),
        startLocation: readString('startLocation'),
        endLocation: readString('endLocation'),
        score: readInt('score'),
        maxScore: readInt('maxScore'),
        percent: readDouble('percent'),
        itemsFound: readInt('itemsFound'),
        maxItemsFound: readInt('maxItemsFound'),
        subCategoriesCompleted: readInt('subCategoriesCompleted'),
        categoriesCompleted: readInt('categoriesCompleted'),
        totalCategories: readInt('totalCategories'),
        totalSubCategories: readInt('totalSubCategories'),
        finalRankIndex: readInt('finalRankIndex'),
        perfectRun: readBool('perfectRun'),
        startTime: readDate('startTime'),
        endTime: readDate('endTime'),
        doubleItemsFound: readInt('doubleItemsFound'),
        totalDoubleItems: readInt('totalDoubleItems'),
        doubleScore: readInt('doubleScore'),
        doubleMaxScore: readInt('doubleMaxScore'),
        tripleItemsFound: readInt('tripleItemsFound'),
        totalTripleItems: readInt('totalTripleItems'),
        tripleScore: readInt('tripleScore'),
        tripleMaxScore: readInt('tripleMaxScore'),
        oneScore: readInt('oneScore'),
        oneMaxScore: readInt('oneMaxScore'),
        twoScore: readInt('twoScore'),
        twoMaxScore: readInt('twoMaxScore'),
        threeScore: readInt('threeScore'),
        threeMaxScore: readInt('threeMaxScore'),
        fourScore: readInt('fourScore'),
        fourMaxScore: readInt('fourMaxScore'),
        completedAchievementIds: List<String>.from(
          data['completedAchievementIds'] ?? [],
        ),
        newAchievementIds: Set<String>.from(data['newAchievementIds'] ?? []),
        achievementTotals: Map<String, int>.from(
          data['achievementTotals'] ?? {},
        ),
        achievementFoundCounts: Map<String, int>.from(
          data['achievementFoundCounts'] ?? {},
        ),
      );
    }).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));

    return trips;
  }

  void _resetRunStateForNewTrip() {
    _completedCategoriesShown.clear();
    _completedSubcategoriesShownGlobal.clear();
    _completedAchievements.clear();
    _sessionUnlockedAchievements.clear();
    _completedPointerTiers.clear();
    _achievementItemIds.clear();
    _gameCompletedShown = false;
    _perfectRunShown = false;
    _lastRankIndex = -1;
  }

  Future<void> _resetProgress() async {
    _sessionPollingTimer?.cancel();
    _currentSessionId = null;
    _previousFoundById = Map.from(foundById);
    _previousCompletedCategoriesShown = Set.from(_completedCategoriesShown);
    _previousCompletedSubcategoriesShownGlobal = Set.from(
      _completedSubcategoriesShownGlobal,
    );
    _previousCompletedAchievements = Set.from(_completedAchievements);
    _previousCompletedPointerTiers = Set.from(_completedPointerTiers);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);

    if (!mounted) return;

    setState(() {
      for (final k in foundById.keys.toList()) {
        foundById[k] = false;
      }

      _completedCategoriesShown.clear();
      _gameCompletedShown = false;
      _perfectRunShown = false;
      _completedSubcategoriesShownGlobal.clear();
      _completedAchievements.clear();
      _completedPointerTiers.clear();

      _recomputeCategoryStats();

      // ✅ FIX: properly reset AND recalculate rank
      final newRank = _getRankIndex();
      _lastRankIndex = newRank;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Checklist reset'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            if (_previousFoundById == null) return;

            final prefs = await SharedPreferences.getInstance();

            if (!mounted) return;

            setState(() {
              foundById = Map.from(_previousFoundById!);
              _completedCategoriesShown = Set.from(
                _previousCompletedCategoriesShown ?? {},
              );
              _completedSubcategoriesShownGlobal = Set.from(
                _previousCompletedSubcategoriesShownGlobal ?? {},
              );

              _completedAchievements = Set.from(
                _previousCompletedAchievements ?? {},
              );
              _completedPointerTiers = Set.from(
                _previousCompletedPointerTiers ?? {},
              );

              _recomputeCategoryStats();

              // ✅ FIX: restore rank display properly
              final newRank = _getRankIndex();
              _lastRankIndex = newRank;
            });

            await prefs.setString(prefsKey, jsonEncode(foundById));
          },
        ),
      ),
    );
  }

  Future<void> _requestSfx({
    required int priority,
    required String assetPath,
    double volume = 1.0,
  }) async {
    if (!_soundEnabled) return;

    // If a higher (or equal) priority sound is already active, ignore this request.
    if (priority <= _activeSfxPriority) return;

    _activeSfxPriority = priority;

    await _sfxPlayer.stop();
    await _sfxPlayer.play(AssetSource(assetPath), volume: volume);

    // When playback finishes, release the priority lock (only if nothing higher replaced it)
    _sfxPlayer.onPlayerComplete.first.then((_) {
      if (!mounted) return;
      if (_activeSfxPriority == priority) {
        _activeSfxPriority = 0;
      }
    });
  }

  Future<void> _playCategoryDoneSound() async {
    await _requestSfx(
      priority: SFX_CATEGORY,
      assetPath: 'sounds/category_done.mp3',
    );
  }

  Future<void> _playGameDoneSound() async {
    await _requestSfx(priority: SFX_WIN, assetPath: 'sounds/game_done.mp3');
  }

  Future<void> _playPerfectDoneSound() async {
    await _requestSfx(
      priority: SFX_PERFECT,
      assetPath: 'sounds/perfect_done.mp3',
    );
  }

  Future<void> _playRankUpSound() async {
    await _requestSfx(priority: SFX_RANK, assetPath: 'sounds/rank_up.mp3');
  }

  void _checkRankMilestone() {
    if (_isRestoringState) return;
    final currentRank = _getRankIndex();

    if (_lastRankIndex == -1) {
      _lastRankIndex = currentRank;
      return;
    }

    if (currentRank > _lastRankIndex) {
      _lastRankIndex = currentRank;

      if (_hapticsEnabled) {
        HapticFeedback.mediumImpact();
      }

      Future.delayed(const Duration(milliseconds: 15), () {
        _playRankUpSound();
      });
    }
  }

  void _checkGameCompletion() {
    if (_isRestoringState) return;
    // If already won, do nothing
    if (_gameCompletedShown) return;

    // If perfect run, let the Perfect Run handler take over (no normal win snackbar)
    if (maxScore > 0 && totalScore == maxScore) {
      _gameCompletedShown = true; // still mark as "won"
      return;
    }

    // Normal win condition (80%/90%)
    if (_getProgressPercent() >= _getTargetPercent()) {
      _gameCompletedShown = true;

      if (_hapticsEnabled) {
        HapticFeedback.heavyImpact();
      }

      _playGameDoneSound();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Center(
            child: Text(
              '⭐ Winner winner chicken dinner! ⭐',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
  }

  void _endTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End Trip?'),
          content: const Text('Are you sure you want to end the trip?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;

    if (confirm != true) return;
    // ✅ Check if trip was started
    if (_tripStartTime == null ||
        _currentTripType == null ||
        _currentStartLocation == null ||
        _currentEndLocation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Start a trip first')));
      return;
    }

    final endTime = DateTime.now();

    final percent = _getProgressPercent();

    final tripId = _generateTripId(
      date: endTime,
      start: _currentStartLocation!,
      end: _currentEndLocation!,
    );

    int doubleItemsFound = 0;
    int totalDoubleItems = _bonusItemIds.length;

    int doubleScore = 0;
    int doubleMaxScore = 0;

    int tripleItemsFound = 0;
    int totalTripleItems = _tripleItemIds.length;

    int tripleScore = 0;
    int tripleMaxScore = 0;

    int oneScore = 0;
    int oneMaxScore = 0;

    int twoScore = 0;
    int twoMaxScore = 0;

    int threeScore = 0;
    int threeMaxScore = 0;

    int fourScore = 0;
    int fourMaxScore = 0;

    for (final it in items) {
      final isFound = foundById[it.itemId] == true;

      // ✅ TRIPLE FIRST (3x)
      if (_tripleItemIds.contains(it.itemId)) {
        final itemValue = it.points * 3;

        tripleMaxScore += itemValue;

        if (isFound) {
          tripleItemsFound++;
          tripleScore += itemValue;
        }
      }
      // ✅ DOUBLE SECOND (2x)
      else if (_bonusItemIds.contains(it.itemId)) {
        final itemValue = it.points * 2;

        doubleMaxScore += itemValue;

        if (isFound) {
          doubleItemsFound++;
          doubleScore += itemValue;
        }
      }
    }

    for (final it in items) {
      final isFound = foundById[it.itemId] == true;

      switch (it.points) {
        case 1:
          oneMaxScore++;
          if (isFound) oneScore++;
          break;

        case 2:
          twoMaxScore++;
          if (isFound) twoScore++;
          break;

        case 3:
          threeMaxScore++;
          if (isFound) threeScore++;
          break;

        case 4:
          fourMaxScore++;
          if (isFound) fourScore++;
          break;
      }
    }

    final completedAchievementIds = <String>[];
    final achievementTotals = <String, int>{};
    final achievementFoundCounts = <String, int>{};

    for (final entry in _achievementItemIds.entries) {
      final achievementId = entry.key;
      final itemSet = entry.value;

      final total = itemSet.length;
      final found = itemSet.where((id) => foundById[id] == true).length;

      achievementTotals[achievementId] = total;
      achievementFoundCounts[achievementId] = found;

      if (total > 0 && found == total) {
        completedAchievementIds.add(achievementId);
      }
    }

    final trip = Trip(
      tripId: tripId,
      tripName: _currentTripType!, // using “Trip Description”
      startLocation: _currentStartLocation!,
      endLocation: _currentEndLocation!,
      score: totalScore,
      maxScore: maxScore,
      percent: percent,
      itemsFound: foundById.values.where((v) => v).length,
      maxItemsFound: items.length,
      subCategoriesCompleted: _getCompletedSubCategoryCount(),
      categoriesCompleted: categoryStats.where((c) => c.complete).length,
      doubleItemsFound: doubleItemsFound,
      totalDoubleItems: totalDoubleItems,
      doubleScore: doubleScore,
      doubleMaxScore: doubleMaxScore,
      tripleItemsFound: tripleItemsFound,
      totalTripleItems: totalTripleItems,
      tripleScore: tripleScore,
      tripleMaxScore: tripleMaxScore,

      oneScore: oneScore,
      oneMaxScore: oneMaxScore,
      twoScore: twoScore,
      twoMaxScore: twoMaxScore,
      threeScore: threeScore,
      threeMaxScore: threeMaxScore,
      fourScore: fourScore,
      fourMaxScore: fourMaxScore,
      completedAchievementIds: completedAchievementIds,
      newAchievementIds: _sessionUnlockedAchievements.toSet(),
      achievementTotals: achievementTotals,
      achievementFoundCounts: achievementFoundCounts,
      totalCategories: _getTotalCategories(),
      totalSubCategories: _getTotalSubCategories(),
      finalRankIndex: _getRankIndex(),
      perfectRun: percent >= 100.0,
      startTime: _tripStartTime!,
      endTime: endTime,
    );

    await _saveTripToFirestore(trip);

    if (!mounted) return;

    _lastCompletedTrip = trip;
    // ✅ END Firestore session properly

    if (_currentSessionId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('trip_sessions')
            .doc(_currentSessionId)
            .update({
              'active': false,
              'endedAt': DateTime.now().toIso8601String(),
            });

        if (!mounted) return;
      } catch (e) {
        // optional: silent fail or log later
      }
    }

    // ✅ stop polling
    _sessionPollingTimer?.cancel();

    // ✅ clear current trip after ending
    setState(() {
      _tripStartTime = null;
      _currentTripType = null;
      _currentStartLocation = null;
      _currentEndLocation = null;
      _currentSessionId = null;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripSummaryScreen(trip: trip)),
    );
  }

  void _checkPerfectRun() {
    if (_isRestoringState) return;
    // Perfect Run = exactly 100% of points
    if (_perfectRunShown) return;
    if (maxScore <= 0) return;

    if (totalScore == maxScore) {
      _perfectRunShown = true;

      if (_hapticsEnabled) {
        HapticFeedback.heavyImpact();
      }

      _playPerfectDoneSound();

      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8), // ✅ long
          backgroundColor: Colors.amber[800], // ✅ flashy gold
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: const _PerfectRunContent(), // ✅ pulsing text widget
        ),
      );
    }
  }

  Future<void> _openSettings() async {
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (settingsDialogContext, setDialogState) => AlertDialog(
          title: const Text('Feedback Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Haptics'),
                value: _hapticsEnabled,
                onChanged: (v) async {
                  setDialogState(() => _hapticsEnabled = v);
                  setState(() => _hapticsEnabled = v);

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('haptics_enabled', v);
                },
              ),
              SwitchListTile(
                title: const Text('Sound'),
                value: _soundEnabled,
                onChanged: (v) async {
                  setDialogState(() => _soundEnabled = v);
                  setState(() => _soundEnabled = v);

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('sound_enabled', v);
                },
              ),
              const Divider(),

              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Reset Achievements'),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (confirmDialogContext) {
                      return AlertDialog(
                        title: const Text('Reset achievements?'),
                        content: const Text(
                          'This will permanently remove all recorded achievements. '
                          'They will appear as NEW again when unlocked.\n\n'
                          'Are you sure?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(confirmDialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(confirmDialogContext, true),
                            child: const Text('Reset'),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true) {
                    final prefs = await SharedPreferences.getInstance();

                    // ✅ Clear stored achievements
                    await prefs.remove(achievementsKey);

                    if (!mounted) return;

                    // ✅ Reset in-memory state
                    setState(() {
                      _allTimeAchievements.clear();
                    });

                    Navigator.pop(settingsDialogContext); // close settings

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Achievements reset'),
                        duration: Duration(milliseconds: 1000),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generateSessionId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final now = DateTime.now().millisecondsSinceEpoch;
    String id = '';
    for (int i = 0; i < 4; i++) {
      id += chars[(now + i * 37) % chars.length];
    }
    return id;
  }

  Future<void> _startTripDialog() async {
    final parentContext = context;
    final typeController = TextEditingController();
    final startController = TextEditingController();
    final endController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start Trip'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Trip Description',
                ),
              ),
              TextField(
                controller: startController,
                decoration: const InputDecoration(labelText: 'Start Location'),
              ),
              TextField(
                controller: endController,
                decoration: const InputDecoration(labelText: 'End Location'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final sessionId = _generateSessionId();
                    final sessionBonusIds = _generateBonusItemIds();
                    final sessionTripleIds = _generateTripleItemIds(
                      sessionBonusIds,
                    );

                    await FirebaseFirestore.instance
                        .collection('trip_sessions')
                        .doc(sessionId)
                        .set({
                          'tripName': typeController.text.trim(),
                          'startLocation': startController.text.trim(),
                          'endLocation': endController.text.trim(),
                          'startTime': DateTime.now().toIso8601String(),
                          'active': true,
                          'foundItems': {},
                          'bonusItemIds': sessionBonusIds.toList(),
                          'tripleItemIds': sessionTripleIds.toList(),
                        });
                    if (!mounted) return;
                    setState(() {
                      _currentTripType = typeController.text.trim();
                      _currentStartLocation = startController.text.trim();
                      _currentEndLocation = endController.text.trim();
                      _tripStartTime = DateTime.now();
                      _currentSessionId = sessionId;
                      _lastCompletedTrip = null;
                      _resetRunStateForNewTrip();

                      for (final k in foundById.keys) {
                        foundById[k] = false;
                      }

                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setString(prefsKey, jsonEncode(foundById));
                      });

                      _bonusItemIds = sessionBonusIds;
                      _tripleItemIds = sessionTripleIds;
                      _recomputeCategoryStats();
                      _startSessionPolling();
                    });

                    Navigator.pop(parentContext);

                    Future.delayed(Duration.zero, () {
                      showDialog(
                        context: parentContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Session Created'),
                          content: Text(
                            'Share this code with your teammate:\n\n$sessionId',
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    });
                  },
                  child: const Text('Create Session'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    final controller = TextEditingController();

                    final joinId = await showDialog<String>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Join Session'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Enter Session ID',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, null),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, controller.text),
                            child: const Text('Join'),
                          ),
                        ],
                      ),
                    );

                    if (!mounted) return;

                    if (joinId == null || joinId.trim().isEmpty) return;

                    final normalizedJoinId = joinId.trim().toUpperCase();

                    // Close the outer Start Trip dialog once, before async work.

                    if (Navigator.of(parentContext).canPop()) {
                      Navigator.of(parentContext).pop();
                    }

                    final sessionDoc = await FirebaseFirestore.instance
                        .collection('trip_sessions')
                        .doc(normalizedJoinId)
                        .get();

                    if (!sessionDoc.exists) {
                      if (!mounted) return;
                      ScaffoldMessenger.maybeOf(parentContext)?.showSnackBar(
                        const SnackBar(
                          content: Text('Session not found'),
                          duration: Duration(milliseconds: 1200),
                        ),
                      );
                      return;
                    }

                    final data = sessionDoc.data()!;

                    if (data['active'] != true) {
                      if (!mounted) return;
                      ScaffoldMessenger.maybeOf(parentContext)?.showSnackBar(
                        const SnackBar(
                          content: Text('Session is no longer active'),
                          duration: Duration(milliseconds: 1200),
                        ),
                      );
                      return;
                    }

                    final remoteFoundItems = Map<String, dynamic>.from(
                      data['foundItems'] ?? {},
                    );

                    final loadedFoundMap = <String, bool>{
                      for (final key in foundById.keys) key: false,
                    };

                    for (final entry in remoteFoundItems.entries) {
                      if (loadedFoundMap.containsKey(entry.key)) {
                        loadedFoundMap[entry.key] = entry.value == true;
                      }
                    }

                    final loadedBonusIds = Set<String>.from(
                      data['bonusItemIds'] ?? [],
                    );

                    final loadedTripleIds = Set<String>.from(
                      data['tripleItemIds'] ?? [],
                    );

                    if (!mounted) return;

                    setState(() {
                      _currentSessionId = normalizedJoinId;
                      _currentTripType = data['tripName'] ?? '';
                      _currentStartLocation = data['startLocation'] ?? '';
                      _currentEndLocation = data['endLocation'] ?? '';
                      _tripStartTime =
                          DateTime.tryParse(data['startTime'] ?? '') ??
                          DateTime.now();
                      _lastCompletedTrip = null;
                      _resetRunStateForNewTrip();

                      foundById = loadedFoundMap;

                      _bonusItemIds = loadedBonusIds;
                      _tripleItemIds = loadedTripleIds;
                      _tripleItemIds = data['tripleItemIds'] != null
                          ? Set<String>.from(data['tripleItemIds'])
                          : {};

                      _recomputeCategoryStats();
                      _startSessionPolling();
                    });

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(prefsKey, jsonEncode(foundById));

                    if (!mounted) return;

                    ScaffoldMessenger.maybeOf(parentContext)?.showSnackBar(
                      SnackBar(
                        content: Text('Joined Session $normalizedJoinId'),
                        duration: const Duration(milliseconds: 1200),
                      ),
                    );
                  },

                  child: const Text('Join Session'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _checkAndCelebrateCompletedCategories() {
    if (_isRestoringState || _gameCompletedShown || _perfectRunShown) return;
    for (final stat in categoryStats) {
      if (stat.complete && !_completedCategoriesShown.contains(stat.name)) {
        _completedCategoriesShown.add(stat.name);
        if (_hapticsEnabled) {
          HapticFeedback.mediumImpact();
        }

        if (_soundEnabled) {
          Future.delayed(const Duration(milliseconds: 20), () {
            _playCategoryDoneSound();
          });
        }

        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text("${stat.name} Completed!"),
                ],
              ),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        });
      }
    }
  }

  List<String> _handleAchievementCheck(
    String itemId,
    Map<String, bool> foundById,
  ) {
    final unlockedLabels = <String>[];

    for (final entry in _achievementItemIds.entries) {
      final achievementId = entry.key;
      final itemSet = entry.value;

      if (!itemSet.contains(itemId)) continue;

      final allFound = itemSet.every((id) => foundById[id] == true);

      if (allFound && !_completedAchievements.contains(achievementId)) {
        _completedAchievements.add(achievementId);
        final label = achievementLabels[achievementId] ?? achievementId;
        unlockedLabels.add(label);

        // ✅ Only mark as NEW if this is the first ever unlock
        if (!_allTimeAchievements.contains(achievementId)) {
          _sessionUnlockedAchievements.add(achievementId);
          _allTimeAchievements.add(achievementId);

          SharedPreferences.getInstance().then((prefs) {
            prefs.setStringList(achievementsKey, _allTimeAchievements.toList());
          });
        }
      }
    }

    return unlockedLabels;
  }

  List<int> _handlePointerTierCheck(Map<String, bool> foundById) {
    final unlockedTiers = <int>[];

    for (final tier in pointerTierLabels.keys) {
      if (_completedPointerTiers.contains(tier)) continue;

      final tierItems = items.where((it) => it.points == tier).toList();
      if (tierItems.isEmpty) continue;

      final allFound = tierItems.every((it) => foundById[it.itemId] == true);

      if (allFound) {
        _completedPointerTiers.add(tier);
        unlockedTiers.add(tier);
      }
    }

    return unlockedTiers;
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car Trip')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error:\n$error'),
          ),
        ),
      );
    }

    final percentTotal = (maxScore == 0)
        ? 0.0
        : (totalScore * 100.0 / maxScore);
    final threshold = winningThresholdPercent(DateTime.now());
    final isWinning = percentTotal >= threshold;
    final currentRankIndex = _getRankIndex();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Car Trip',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        actions: [
          if (_lastCompletedTrip != null)
            IconButton(
              tooltip: 'Last Summary',
              icon: const Icon(Icons.receipt_long),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TripSummaryScreen(trip: _lastCompletedTrip!),
                  ),
                );
              },
            ),

          TextButton.icon(
            icon: Icon(_tripStartTime == null ? Icons.play_arrow : Icons.stop),
            label: Text(_tripStartTime == null ? 'START' : 'END'),
            onPressed: () {
              if (_tripStartTime == null) {
                _startTripDialog();
              } else {
                _endTrip();
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) async {
              switch (value) {
                case 'load':
                  try {
                    final trips = await _loadTripsFromFirestore();
                    if (!mounted) return;

                    if (trips.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripSummaryScreen(trip: trips.first),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No trips found')),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to load trip data: $e')),
                    );
                  }
                  break;

                case 'history':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TripHistoryScreen(loadTrips: _loadTripsFromFirestore),
                    ),
                  );
                  break;

                case 'ranks':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RankListScreen()),
                  );
                  break;

                case 'settings':
                  _openSettings();
                  break;

                case 'reset':
                  _resetProgress();
                  break;

                case 'achievements':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AchievementsScreen(
                        achievementItemIds: _achievementItemIds,
                        foundById: foundById,
                      ),
                    ),
                  );
                  break;
                case 'sort_az':
                  setState(() {
                    sortMode = SortMode.az;
                    _recomputeCategoryStats();
                  });
                  break;

                case 'sort_least_items':
                  setState(() {
                    sortMode = SortMode.leastItemsLeft;
                    _recomputeCategoryStats();
                  });
                  break;

                case 'sort_most_items':
                  setState(() {
                    sortMode = SortMode.mostItemsLeft;
                    _recomputeCategoryStats();
                  });
                  break;

                case 'sort_least_points':
                  setState(() {
                    sortMode = SortMode.leastPointsLeft;
                    _recomputeCategoryStats();
                  });
                  break;

                case 'sort_most_points':
                  setState(() {
                    sortMode = SortMode.mostPointsLeft;
                    _recomputeCategoryStats();
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'load',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('📄', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Last Trip Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('🗄️', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Trip Archives'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'ranks',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('🏆', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Rank List'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'achievements',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('🎯', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Achievements'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('⚙️', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Settings'),
                  ],
                ),
              ),

              // ✅ Sort options (now aligned too)
              const PopupMenuItem(
                value: 'sort_az',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('🅰️', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Sort: A-Z'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sort_least_items',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('🔽', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Sort: Least Items'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sort_most_items',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('🔼', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Sort: Most Items'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sort_least_points',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('📉', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Sort: Least Points'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sort_most_points',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('📈', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('Sort: Most Points'),
                  ],
                ),
              ),

              // ✅ Reset (already correct, just kept consistent)
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Center(
                        child: Text('🔄', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('FULL RESET'),
                  ],
                ),
              ),
            ],

            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.menu, size: 18),
                    SizedBox(width: 4),
                    Text(
                      'MENU',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tripStartTime != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.green.withValues(alpha: 0.06),
              child: Text(
                '🚗 ${_currentTripType ?? ''} • ${_currentStartLocation ?? ''} → ${_currentEndLocation ?? ''} • ${_tripStartTime!.hour.toString().padLeft(2, '0')}:${_tripStartTime!.minute.toString().padLeft(2, '0')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.blue.withValues(alpha: 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Score: $totalScore/$maxScore (${percentTotal.toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '>= ${_getTargetPercent().toStringAsFixed(1)}% (${_getDayName()})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (percentTotal / 100.0).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progressColor(percentTotal / 100.0),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Achieved: ${_getCompletedAchievementCount()} / ${_getTotalAchievementCount()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 1200),
                          switchInCurve: Curves.easeInOutBack,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            final scale = Tween<double>(
                              begin: 0.40,
                              end: 1.1,
                            ).animate(animation);
                            return ScaleTransition(
                              scale: scale,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: RankBadge(
                            key: ValueKey<int>(currentRankIndex),
                            text: 'Rank: ${kRanks[currentRankIndex]}',
                            color: rankColor(currentRankIndex),
                          ),
                        ),
                      ],
                    ),

                    if (isWinning)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You Won! ${dayName(DateTime.now())} target met (≥ ${threshold.toStringAsFixed(1)}%).',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: categoryStats.length,
              itemBuilder: (context, index) {
                final stat = categoryStats[index];
                final p = stat.progress;
                final percent = (p * 100).round();
                final remaining = stat.remainingCount;
                final color = _progressColor(p);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final filtered = items
                          .where((it) => it.category == stat.name)
                          .toList();

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubCategoryScreen(
                            category: stat.name,
                            items: filtered,
                            foundById: foundById,
                            onToggle: _toggleAndPersist,
                            initialSortMode: sortMode,
                            hapticsEnabled: _hapticsEnabled,
                            soundEnabled: _soundEnabled,
                            playSfx: _requestSfx,
                            completedSubcategoriesShown:
                                _completedSubcategoriesShownGlobal,
                            isTripActive: _tripStartTime != null,
                            bonusItemIds: _bonusItemIds,
                            tripleItemIds: _tripleItemIds,
                            onAchievementCheck: _handleAchievementCheck,
                            onPointerTierCheck: _handlePointerTierCheck,
                            isGameComplete:
                                _gameCompletedShown || _perfectRunShown,
                          ),
                        ),
                      );

                      setState(() {
                        _recomputeCategoryStats();
                      });

                      _checkRankMilestone();
                      _checkAndCelebrateCompletedCategories();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(
                              resolveIcon(
                                iconName: stat.iconName,
                                groupName: stat.name,
                              ),
                              color: color,
                              size: 50,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stat.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: p,
                                    minHeight: 8,
                                    backgroundColor: Colors.black12,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      color,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${stat.found}/${stat.total} • $percent% • $remaining left',
                                ),
                                Text(
                                  'Total Score: ${stat.score}/${stat.maxScore}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RankBadge extends StatelessWidget {
  final String text;
  final Color color;

  const RankBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.55, end: 0.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (context, flashOpacity, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: flashOpacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/* -------------------------
   SUBCATEGORY SCREEN
-------------------------- */

class SubCategoryScreen extends StatefulWidget {
  final String category;
  final List<TripItem> items;
  final Map<String, bool> foundById;
  final Future<void> Function(String, bool) onToggle;
  final SortMode initialSortMode;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool isTripActive;
  final Set<String> bonusItemIds;
  final Set<String> tripleItemIds;
  final bool isGameComplete;
  final List<String> Function(String, Map<String, bool>) onAchievementCheck;
  final List<int> Function(Map<String, bool>) onPointerTierCheck;
  final Future<void> Function({
    required int priority,
    required String assetPath,
    double volume,
  })?
  playSfx;
  final Set<String> completedSubcategoriesShown;

  const SubCategoryScreen({
    super.key,
    required this.category,
    required this.items,
    required this.foundById,
    required this.onToggle,
    required this.initialSortMode,
    required this.hapticsEnabled,
    required this.soundEnabled,
    this.playSfx,
    required this.completedSubcategoriesShown,
    required this.isTripActive,
    required this.bonusItemIds,
    required this.tripleItemIds,
    required this.isGameComplete,
    required this.onAchievementCheck,
    required this.onPointerTierCheck,
  });

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  bool hideDone = true;

  List<GroupStat> subStats = [];
  int categoryScore = 0;
  int categoryMaxScore = 0;

  late SortMode sortMode;

  Future<void> _initHideDone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('hide_done_${widget.category}');

    if (!mounted) return;

    setState(() {
      hideDone = saved ?? true;
    });
  }

  @override
  void initState() {
    super.initState();
    _initHideDone();

    sortMode = widget.initialSortMode;
    _recomputeSubStats();
    _checkAndCelebrateCompletedSubcategories();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _applySort(List<GroupStat> list) {
    switch (sortMode) {
      case SortMode.az:
        list.sort((a, b) {
          if (a.complete != b.complete) {
            return a.complete ? 1 : -1;
          }
          return a.name.compareTo(b.name);
        });
        break;
      case SortMode.leastItemsLeft:
        list.sort((a, b) => a.remainingCount.compareTo(b.remainingCount));
        break;
      case SortMode.mostItemsLeft:
        list.sort((a, b) => b.remainingCount.compareTo(a.remainingCount));
        break;
      case SortMode.leastPointsLeft:
        list.sort((a, b) => a.scoreRemaining.compareTo(b.scoreRemaining));
        break;
      case SortMode.mostPointsLeft:
        list.sort((a, b) => b.scoreRemaining.compareTo(a.scoreRemaining));
        break;
    }
  }

  void _recomputeSubStats() {
    final totals = <String, int>{};
    final founds = <String, int>{};
    final scores = <String, int>{};
    final maxScores = <String, int>{};
    final iconCounts = <String, Map<String, int>>{};

    categoryScore = 0;
    categoryMaxScore = 0;

    for (final it in widget.items) {
      totals[it.subCategory] = (totals[it.subCategory] ?? 0) + 1;
      maxScores[it.subCategory] = (maxScores[it.subCategory] ?? 0) + it.points;
      categoryMaxScore += it.points;

      iconCounts.putIfAbsent(it.subCategory, () => <String, int>{});
      final m = iconCounts[it.subCategory]!;
      final key = it.iconName.isEmpty ? 'category' : it.iconName;
      m[key] = (m[key] ?? 0) + 1;

      if (widget.foundById[it.itemId] == true) {
        founds[it.subCategory] = (founds[it.subCategory] ?? 0) + 1;
        scores[it.subCategory] = (scores[it.subCategory] ?? 0) + it.points;
        categoryScore += it.points;
      }
    }

    final list = <GroupStat>[];
    for (final sub in totals.keys) {
      final counts = iconCounts[sub] ?? {};
      String chosen = 'category';
      int best = -1;
      counts.forEach((k, v) {
        if (v > best) {
          best = v;
          chosen = k;
        }
      });

      list.add(
        GroupStat(
          name: sub,
          found: founds[sub] ?? 0,
          total: totals[sub] ?? 0,
          score: scores[sub] ?? 0,
          maxScore: maxScores[sub] ?? 0,
          iconName: chosen,
        ),
      );
    }

    _applySort(list);
    subStats = list;
  }

  Future<void> _checkAndCelebrateCompletedSubcategories() async {
    if (widget.isGameComplete) return;
    for (final stat in subStats) {
      if (stat.complete &&
          !widget.completedSubcategoriesShown.contains(stat.name)) {
        widget.completedSubcategoriesShown.add(stat.name);
        if (widget.hapticsEnabled) {
          HapticFeedback.selectionClick();
        }

        if (widget.soundEnabled && widget.playSfx != null) {
          Future.delayed(const Duration(milliseconds: 15), () {
            widget.playSfx!(
              priority: SFX_SUB,
              assetPath: 'sounds/sub_done.mp3',
              volume: 0.6,
            );
          });
        }

        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text("${stat.name} Completed!"),
                ],
              ),

              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryPercent = (categoryMaxScore == 0)
        ? 0.0
        : (categoryScore * 100.0 / categoryMaxScore);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        centerTitle: false,
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<SortMode>(
              value: sortMode,
              onChanged: (m) {
                if (m == null) return;
                setState(() {
                  sortMode = m;
                  _recomputeSubStats();
                });
                _checkAndCelebrateCompletedSubcategories();
              },
              items: SortMode.values
                  .map(
                    (m) =>
                        DropdownMenuItem(value: m, child: Text(sortLabel(m))),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.blue.withValues(alpha: 0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Text(
                  'Category Score',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$categoryScore / $categoryMaxScore  (${categoryPercent.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: subStats.length,
              itemBuilder: (context, index) {
                final stat = subStats[index];
                final p = stat.progress;
                final percent = (p * 100).round();
                final remaining = stat.remainingCount;
                final color = _progressColor(p);

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final filtered = widget.items
                          .where((it) => it.subCategory == stat.name)
                          .toList();

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemScreen(
                            title: stat.name,
                            items: filtered,
                            foundById: widget.foundById,
                            onToggle: widget.onToggle,
                            isTripActive: widget.isTripActive,
                            bonusItemIds: widget.bonusItemIds,
                            tripleItemIds: widget.tripleItemIds,
                            playSfx: widget.playSfx,
                            onAchievementCheck: widget.onAchievementCheck,
                            onPointerTierCheck: widget.onPointerTierCheck,
                          ),
                        ),
                      );

                      setState(() {
                        _recomputeSubStats();
                      });

                      _checkAndCelebrateCompletedSubcategories();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(
                              resolveIcon(
                                iconName: stat.iconName,
                                groupName: stat.name,
                              ),
                              color: color,
                              size: 50,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stat.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: p,
                                    minHeight: 8,
                                    backgroundColor: Colors.black12,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      color,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${stat.found}/${stat.total} • $percent% • $remaining left',
                                ),
                                Text(
                                  'Score: ${stat.score}/${stat.maxScore}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------------
   ITEM SCREEN
-------------------------- */

class ItemScreen extends StatefulWidget {
  final String title;
  final List<TripItem> items;
  final Map<String, bool> foundById;
  final Future<void> Function(String, bool) onToggle;
  final bool isTripActive;
  final Set<String> bonusItemIds;
  final Set<String> tripleItemIds;

  final Future<void> Function({
    required int priority,
    required String assetPath,
    double volume,
  })?
  playSfx;
  final List<String> Function(String, Map<String, bool>) onAchievementCheck;
  final List<int> Function(Map<String, bool>) onPointerTierCheck;
  const ItemScreen({
    super.key,
    required this.title,
    required this.items,
    required this.foundById,
    required this.onToggle,
    required this.isTripActive,
    required this.bonusItemIds,
    required this.tripleItemIds,
    required this.playSfx,
    required this.onAchievementCheck,
    required this.onPointerTierCheck,
  });

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  bool hideDone = true;

  Future<void> _initHideDone() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('hide_done_${widget.title}');

    if (!mounted) return;

    setState(() {
      hideDone = saved ?? true;
    });
  }

  @override
  void initState() {
    super.initState();
    _initHideDone();
  }

  @override
  Widget build(BuildContext context) {
    late final List<TripItem> visible;

    if (hideDone) {
      visible = widget.items
          .where((it) => widget.foundById[it.itemId] != true)
          .toList();
    } else {
      visible = widget.items;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        actions: [
          Row(
            children: [
              const Text('Hide done'),
              Switch(
                value: hideDone,
                onChanged: (v) async {
                  setState(() {
                    hideDone = v;
                  });

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('hide_done_${widget.title}', hideDone);
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final it = visible[index];
          final checked = widget.foundById[it.itemId] == true;

          return CheckboxListTile(
            title: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(text: '${it.name}  (+${it.points})'),

                  if (widget.tripleItemIds.contains(it.itemId))
                    const TextSpan(text: '  '),

                  if (widget.tripleItemIds.contains(it.itemId))
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade600,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: const Text(
                          'TRIPLE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),

                  if (!widget.tripleItemIds.contains(it.itemId) &&
                      widget.bonusItemIds.contains(it.itemId))
                    const TextSpan(text: '  '),

                  if (!widget.tripleItemIds.contains(it.itemId) &&
                      widget.bonusItemIds.contains(it.itemId))
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.black, width: 1),
                        ),
                        child: const Text(
                          'DOUBLE',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            secondary: Icon(
              resolveIcon(iconName: it.iconName, groupName: it.subCategory),
              size: 36,
            ),
            value: checked,

            onChanged: (v) async {
              if (!widget.isTripActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Start a trip first'),
                    duration: const Duration(milliseconds: 500),
                  ),
                );

                return;
              }

              final newVal = v ?? false;

              setState(() {
                widget.foundById[it.itemId] = newVal;
              });

              final unlockedAchievements = newVal
                  ? widget.onAchievementCheck(it.itemId, widget.foundById)
                  : <String>[];

              final unlockedPointerTiers = newVal
                  ? widget.onPointerTierCheck(widget.foundById)
                  : <int>[];

              if (newVal &&
                  widget.tripleItemIds.contains(it.itemId) &&
                  widget.playSfx != null) {
                widget.playSfx!(
                  priority: SFX_DOUBLE,
                  assetPath: 'sounds/triple_done.mp3',
                  volume: 1.0,
                );
              } else if (newVal &&
                  widget.bonusItemIds.contains(it.itemId) &&
                  widget.playSfx != null) {
                widget.playSfx!(
                  priority: SFX_DOUBLE,
                  assetPath: 'sounds/double_done.mp3',
                  volume: 1.0,
                );
              }

              if (newVal && unlockedAchievements.isNotEmpty) {
                // ✅ PLAY achievement sound
                if (widget.playSfx != null) {
                  widget.playSfx!(
                    priority: SFX_ACHIEVEMENT,
                    assetPath: 'sounds/achievement_done.mp3',
                    volume: 1.0,
                  );
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text(unlockedAchievements.join(' • '))),
                      ],
                    ),
                    backgroundColor: Colors.pink,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ),
                );
              } else if (newVal && unlockedPointerTiers.isNotEmpty) {
                final pointerLabel =
                    pointerTierLabels[unlockedPointerTiers.first] ??
                    'Tier complete!';
                if (widget.playSfx != null) {
                  final tier = unlockedPointerTiers.first;
                  String assetPath;
                  switch (tier) {
                    case 1:
                      assetPath = 'sounds/one_pointer_done.mp3';
                      break;
                    case 2:
                      assetPath = 'sounds/two_pointer_done.mp3';
                      break;
                    case 3:
                      assetPath = 'sounds/three_pointer_done.mp3';
                      break;
                    case 4:
                      assetPath = 'sounds/four_pointer_done.mp3';
                      break;
                    default:
                      assetPath = 'sounds/one_pointer_done.mp3';
                  }
                  widget.playSfx!(
                    priority: SFX_POINTER,
                    assetPath: assetPath,
                    volume: 1.0,
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text(pointerLabel)),
                      ],
                    ),
                    backgroundColor: Colors.purple,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 3000),
                  ),
                );
              }

              await widget.onToggle(it.itemId, newVal);
            },
          );
        },
      ),
    );
  }
}

class _PerfectRunContent extends StatefulWidget {
  const _PerfectRunContent();

  @override
  State<_PerfectRunContent> createState() => _PerfectRunContentState();
}

class _PerfectRunContentState extends State<_PerfectRunContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scale,
        child: const Text(
          '⭐ PERFECT RUN — 100% COMPLETE! ⭐',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class TripHistoryScreen extends StatefulWidget {
  final Future<List<Trip>> Function() loadTrips;

  const TripHistoryScreen({super.key, required this.loadTrips});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _tripsFuture = widget.loadTrips();
  }

  String _formatHistoryDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year.toString();

    return '$day $month $year';
  }

  String _formatHistoryDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final minutes = diff.inMinutes;

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }

  Future<void> _confirmDeleteTrip(Trip trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete trip?'),
          content: Text(
            'Are you sure you want to delete "${trip.tripName}"?\n\n'
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('trips')
          .doc(trip.tripId)
          .delete();

      setState(() {
        _tripsFuture = widget.loadTrips();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip deleted'),
          duration: Duration(milliseconds: 1000),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Archives')),
      body: FutureBuilder<List<Trip>>(
        future: _tripsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error loading trips:\n${snapshot.error}'),
              ),
            );
          }

          final trips = snapshot.data ?? [];

          if (trips.isEmpty) {
            return const Center(child: Text('No trips yet'));
          }

          if (trips.isEmpty) {
            return const Center(child: Text('No trips yet'));
          }

          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TripSummaryScreen(trip: trip),
                    ),
                  );
                },
                onLongPress: () async {
                  await _confirmDeleteTrip(trip);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.black12, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              trip.tripName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _progressColor(
                                (trip.percent / 100).clamp(0.0, 1.0),
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${trip.percent.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${trip.startLocation} → ${trip.endLocation}',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatHistoryDate(trip.startTime)} • ${_formatHistoryDuration(trip.startTime, trip.endTime)}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          kRanks[trip.finalRankIndex],
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: rankColor(trip.finalRankIndex),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TripSummaryScreen extends StatelessWidget {
  final Trip trip;

  const TripSummaryScreen({super.key, required this.trip});

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final diff = end.difference(start);

    final minutes = diff.inMinutes;

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remainingMinutes}m';
  }

  String _formatRate(int value, DateTime start, DateTime end) {
    final minutes = end.difference(start).inMinutes;

    if (minutes == 0) return '0';

    final rate = value / minutes;

    return rate.toStringAsFixed(1);
  }

  TableRow _tableRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(alignment: Alignment.centerLeft, child: Text(value)),
        ),
      ],
    );
  }

  TableRow _achievementRow(
    String label,
    bool completed,
    int found,
    int total,
    bool isNew,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$label (${found}/${total})',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  completed ? Icons.check : Icons.close,
                  color: completed ? Colors.green : Colors.red,
                ),
                if (isNew) ...[
                  const SizedBox(width: 6),
                  const Text(
                    'NEW',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Complete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Builder(
              builder: (context) {
                final isPerfect = trip.percent >= 100.0;
                final isWinning =
                    trip.percent >= winningThresholdPercent(DateTime.now());

                if (isPerfect) {
                  return const Column(
                    children: [
                      Text(
                        '⭐ PERFECT RUN ⭐',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      SizedBox(height: 10),
                    ],
                  );
                }

                if (isWinning) {
                  return Column(
                    children: [
                      Text(
                        '⭐ WINNING RUN ⭐',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                }

                return const Column(
                  children: [
                    Text(
                      'BETTER LUCK NEXT TIME',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 10),
                  ],
                );
              },
            ),
            Builder(
              builder: (context) {
                final isPerfect = trip.percent >= 100.0;
                final isWinning =
                    trip.percent >= winningThresholdPercent(DateTime.now());

                Color color;

                if (isPerfect) {
                  color = Colors.amber;
                } else if (isWinning) {
                  color = Colors.green.shade600;
                } else {
                  color = Colors.red;
                }

                return Text(
                  'Final Score: ${trip.percent.toStringAsFixed(1)}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),

            Text(
              'Target to Win >= ${winningThresholdPercent(DateTime.now()).toStringAsFixed(1)}% (${dayName(DateTime.now())})',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 10),

            // --- Trip Identity ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '🎮 Game Statistics',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 1),
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: [
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            height: 36,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Final Rank',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: RankBadge(
                          text: kRanks[trip.finalRankIndex],
                          color: rankColor(trip.finalRankIndex),
                        ),
                      ),
                    ),
                  ],
                ),
                _tableRow('Score', '${trip.score} / ${trip.maxScore}'),
                _tableRow(
                  'Score/min',
                  _formatRate(trip.score, trip.startTime, trip.endTime),
                ),
                _tableRow(
                  'Items',
                  '${trip.itemsFound} / ${trip.maxItemsFound}',
                ),
                _tableRow(
                  'Items/min',
                  _formatRate(trip.itemsFound, trip.startTime, trip.endTime),
                ),

                _tableRow(
                  'Sub-Categories',
                  '${trip.subCategoriesCompleted} / ${trip.totalSubCategories}',
                ),

                _tableRow(
                  'Categories',
                  '${trip.categoriesCompleted} / ${trip.totalCategories}',
                ),

                _tableRow(
                  'Doubles Found',
                  '${trip.doubleItemsFound} / ${trip.totalDoubleItems}',
                ),

                _tableRow(
                  'Doubles Contribution',
                  '${trip.doubleScore} / ${trip.doubleMaxScore} '
                      '(${trip.doubleMaxScore == 0 ? "0" : ((trip.doubleScore / trip.doubleMaxScore) * 100).toStringAsFixed(1)}%)',
                ),

                _tableRow(
                  '4-pointers',
                  '${trip.fourScore} / ${trip.fourMaxScore} '
                      '(${trip.fourMaxScore == 0 ? "0" : ((trip.fourScore / trip.fourMaxScore) * 100).toStringAsFixed(1)}%)'
                      '${trip.fourMaxScore > 0 && trip.fourScore == trip.fourMaxScore ? "\n✅ ${pointerTierLabels[4]}" : ""}',
                ),

                _tableRow(
                  '3-pointers',
                  '${trip.threeScore} / ${trip.threeMaxScore} '
                      '(${trip.threeMaxScore == 0 ? "0" : ((trip.threeScore / trip.threeMaxScore) * 100).toStringAsFixed(1)}%)'
                      '${trip.threeMaxScore > 0 && trip.threeScore == trip.threeMaxScore ? "\n✅ ${pointerTierLabels[3]}" : ""}',
                ),

                _tableRow(
                  '2-pointers',
                  '${trip.twoScore} / ${trip.twoMaxScore} '
                      '(${trip.twoMaxScore == 0 ? "0" : ((trip.twoScore / trip.twoMaxScore) * 100).toStringAsFixed(1)}%)'
                      '${trip.twoMaxScore > 0 && trip.twoScore == trip.twoMaxScore ? "\n✅ ${pointerTierLabels[2]}" : ""}',
                ),

                _tableRow(
                  '1-pointers',
                  '${trip.oneScore} / ${trip.oneMaxScore} '
                      '(${trip.oneMaxScore == 0 ? "0" : ((trip.oneScore / trip.oneMaxScore) * 100).toStringAsFixed(1)}%)'
                      '${trip.oneMaxScore > 0 && trip.oneScore == trip.oneMaxScore ? "\n✅ ${pointerTierLabels[1]}" : ""}',
                ),

                _tableRow(
                  'Achievements Completed',
                  '${trip.completedAchievementIds.length} / ${achievementLabels.length}',
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '🚗 Travel Statistics',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 1),
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },

              children: [
                _tableRow('Trip Description', trip.tripName),

                _tableRow(
                  'Route',
                  '${trip.startLocation} → ${trip.endLocation}',
                ),

                _tableRow(
                  'Date',
                  DateFormat('EEE d MMM yyyy').format(trip.startTime),
                ),
                _tableRow('Start Time', _formatTime(trip.startTime)),
                _tableRow('End Time', _formatTime(trip.endTime)),
                _tableRow(
                  'Duration',
                  _formatDuration(trip.startTime, trip.endTime),
                ),

                _tableRow('ID', trip.tripId),
              ],
            ),
            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '🏆 Achievements Discovered',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 10),

            Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 1),
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: [
                for (final entry
                    in achievementLabels.entries.toList()
                      ..sort((a, b) => a.value.compareTo(b.value)))
                  _achievementRow(
                    entry.value,
                    trip.completedAchievementIds.contains(entry.key),
                    trip.achievementFoundCounts[entry.key] ?? 0,
                    trip.achievementTotals[entry.key] ?? 0,
                    trip.newAchievementIds.contains(entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class RankListScreen extends StatelessWidget {
  const RankListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Rank List')),

      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: kRanks.length,
        itemBuilder: (context, index) {
          final label = kRanks[index];

          String percentText;

          if (index == 9) {
            percentText = '90.0 - 94.9%'; // Apex
          } else if (index == 10) {
            percentText = '95.0 - 100.0%'; // GOAT
          } else {
            percentText =
                '${(index * 10).toStringAsFixed(1)} - ${(((index + 1) * 10) - 0.1).toStringAsFixed(1)}%';
          }

          return _rankRow(percentText, label, index);
        },
      ),
    );
  }

  Widget _rankRow(String range, String label, int index) {
    final color = rankColor(index);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            // ✅ LEFT SIDE (Rank)
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: color, // ✅ added
                ),
              ),
            ),

            // ✅ RIGHT SIDE (Percentage)
            Text(
              range,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: color, // ✅ added
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AchievementsScreen extends StatelessWidget {
  final Map<String, Set<String>> achievementItemIds;
  final Map<String, bool> foundById;

  const AchievementsScreen({
    super.key,
    required this.achievementItemIds,
    required this.foundById,
  });

  int _countFound(Set<String> ids, Map<String, bool> foundMap) {
    int count = 0;
    for (final id in ids) {
      if (foundMap[id] == true) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final achievementIds = achievementItemIds.keys.toList()
      ..sort((a, b) {
        final labelA = achievementLabels[a] ?? a;
        final labelB = achievementLabels[b] ?? b;
        return labelA.compareTo(labelB);
      });

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Achievements')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: achievementIds.length,
        itemBuilder: (context, index) {
          final id = achievementIds[index];
          final label = achievementLabels[id] ?? id;
          final items = achievementItemIds[id]!;

          final total = items.length;
          final found = _countFound(items, foundById);
          final isComplete = found == total;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 2, // 🔽 smaller → tighter rows
              ),
              title: Text(
                '$label ($found/$total)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
                  color: isComplete ? Colors.green.shade700 : null,
                ),
              ),
              trailing: isComplete
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
