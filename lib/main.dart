import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_symbols_icons/symbols_map.dart';

void main() => runApp(const CarTripApp());

class CarTripApp extends StatelessWidget {
  const CarTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Trip Game',
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

  TripItem({
    required this.category,
    required this.subCategory,
    required this.name,
    required this.itemId,
    required this.iconName,
    required this.points,
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
  });
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

enum SortMode { az, progressDesc, remainingDesc, pointsRemainingDesc }

// Sound priorities (higher number = more important)
const int SFX_SUB = 1;
const int SFX_CATEGORY = 2;
const int SFX_RANK = 3;
const int SFX_WIN = 4;
const int SFX_PERFECT = 5;
const List<String> kRanks = [
  'Noob',
  'Novice',
  'Rookie',
  'Amateur',
  'Mid',
  'Decent',
  'Master',
  'Expert',
  'Legendary',
  'God-Like',
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
  ];
  return colors[idx.clamp(0, colors.length - 1)];
}

String sortLabel(SortMode mode) {
  switch (mode) {
    case SortMode.az:
      return 'A-Z';
    case SortMode.progressDesc:
      return 'Almost complete';
    case SortMode.remainingDesc:
      return 'Most left';
    case SortMode.pointsRemainingDesc:
      return 'Most points left';
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
  static const csvPath = 'assets/Car Trip List App Latest Version.csv';

  List<TripItem> items = [];
  Map<String, bool> foundById = {};
  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _hapticsEnabled = true;
  bool _soundEnabled = true;

  Map<String, bool>? _previousFoundById;
  Set<String>? _previousCompletedCategoriesShown;

  List<GroupStat> categoryStats = [];

  int totalScore = 0;

  int maxScore = 0;

  bool loading = true;
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

  bool _gameCompletedShown = false;
  bool _perfectRunShown = false;
  int _lastRankIndex = -1;

  // Tracks the priority of the sound currently allowed to play
  int _activeSfxPriority = 0;

  @override
  void initState() {
    super.initState();

    _loadAll();
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
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

      items = parsed;
      foundById = freshFound;

      _recomputeCategoryStats();

      setState(() => loading = false);

      // If anything is already complete, celebrate once
      _checkAndCelebrateCompletedCategories();
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  double _getTargetPercent() {
    return winningThresholdPercent(DateTime.now());
  }

  String _getDayName() {
    const days = ['Mon.', 'Tue.', 'Wed.', 'Thu.', 'Fri.', 'Sat.', 'Sun.'];
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

    return '${datePart}_${startClean}_${endClean}';
  }

  int _getRankIndex() {
    final progress = _getProgressPercent();
    final target = _getTargetPercent();

    final stepSize = target / 10;

    int index = (progress / stepSize).floor();

    if (index >= 9) index = 9;

    return index;
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

  void _applySort(List<GroupStat> list) {
    switch (sortMode) {
      case SortMode.az:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortMode.progressDesc:
        list.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      case SortMode.remainingDesc:
        list.sort((a, b) => b.remainingCount.compareTo(a.remainingCount));
        break;
      case SortMode.pointsRemainingDesc:
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

    for (final it in items) {
      totals[it.category] = (totals[it.category] ?? 0) + 1;
      maxScores[it.category] = (maxScores[it.category] ?? 0) + it.points;
      maxScore += it.points;

      iconCounts.putIfAbsent(it.category, () => <String, int>{});
      final m = iconCounts[it.category]!;
      final key = it.iconName.isEmpty ? 'category' : it.iconName;
      m[key] = (m[key] ?? 0) + 1;

      if (foundById[it.itemId] == true) {
        founds[it.category] = (founds[it.category] ?? 0) + 1;
        scores[it.category] = (scores[it.category] ?? 0) + it.points;
        totalScore += it.points;
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(foundById));
  }

  Future<void> _resetProgress() async {
    _previousFoundById = Map.from(foundById);
    _previousCompletedCategoriesShown = Set.from(_completedCategoriesShown);
    _previousCompletedSubcategoriesShownGlobal = Set.from(
      _completedSubcategoriesShownGlobal,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);

    setState(() {
      for (final k in foundById.keys.toList()) {
        foundById[k] = false;
      }

      _completedCategoriesShown.clear();
      _gameCompletedShown = false;
      _perfectRunShown = false;
      _completedSubcategoriesShownGlobal.clear();

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

            setState(() {
              foundById = Map.from(_previousFoundById!);
              _completedCategoriesShown = Set.from(
                _previousCompletedCategoriesShown ?? {},
              );
              _completedSubcategoriesShownGlobal = Set.from(
                _previousCompletedSubcategoriesShownGlobal ?? {},
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
      builder: (context) {
        return AlertDialog(
          title: const Text('End Trip?'),
          content: const Text('Are you sure you want to end the trip?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

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

    final trip = Trip(
      tripId: tripId,
      tripName: _currentTripType!, // using “Type of Trip”
      startLocation: _currentStartLocation!,
      endLocation: _currentEndLocation!,
      score: totalScore,
      maxScore: maxScore,
      percent: percent,
      itemsFound: foundById.values.where((v) => v).length,
      maxItemsFound: items.length,
      subCategoriesCompleted: _getCompletedSubCategoryCount(),
      categoriesCompleted: categoryStats.where((c) => c.complete).length,
      totalCategories: _getTotalCategories(),
      totalSubCategories: _getTotalSubCategories(),
      finalRankIndex: _getRankIndex(),
      perfectRun: percent >= 100.0,
      startTime: _tripStartTime!,
      endTime: endTime,
    );

    // ✅ clear current trip after ending
    setState(() {
      _tripStartTime = null;
      _currentTripType = null;
      _currentStartLocation = null;
      _currentEndLocation = null;
    });

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TripSummaryScreen(trip: trip)),
    );
  }

  void _checkPerfectRun() {
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
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Feedback settings'),
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startTripDialog() async {
    final typeController = TextEditingController();
    final startController = TextEditingController();
    final endController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Start Trip'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Type of Trip'),
              ),
              TextField(
                controller: startController,
                decoration: const InputDecoration(labelText: 'Location Start'),
              ),
              TextField(
                controller: endController,
                decoration: const InputDecoration(labelText: 'Location End'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentTripType = typeController.text.trim();
                  _currentStartLocation = startController.text.trim();
                  _currentEndLocation = endController.text.trim();
                  _tripStartTime = DateTime.now();
                });

                Navigator.pop(context);
              },
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
  }

  void _checkAndCelebrateCompletedCategories() {
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

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car Trip Game')),
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
        title: const Text('Car Trip Game'),
        actions: [
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

          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: 'Reset progress',
            icon: const Icon(Icons.refresh),
            onPressed: _resetProgress,
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
                  children: [
                    Expanded(
                      child: Text(
                        'Total Score: $totalScore / $maxScore  (${percentTotal.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<SortMode>(
                        value: sortMode,
                        onChanged: (m) {
                          if (m == null) return;
                          setState(() {
                            sortMode = m;
                            _recomputeCategoryStats();
                          });
                        },
                        items: SortMode.values
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(sortLabel(m)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
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
                if (isWinning)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You Won! ${dayName(DateTime.now())} target met (≥ ${threshold.toStringAsFixed(1)}%).',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target >= ${_getTargetPercent().toStringAsFixed(1)}% (${_getDayName()})',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
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
                  fontSize: 16,
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
          // 1. Unfinished before completed
          if (a.complete != b.complete) {
            return a.complete ? 1 : -1;
          }

          // 2. Alphabetical within each group
          return a.name.compareTo(b.name);
        });
        break;

      case SortMode.progressDesc:
        list.sort((a, b) => b.progress.compareTo(a.progress));
        break;

      case SortMode.remainingDesc:
        list.sort((a, b) => b.remainingCount.compareTo(a.remainingCount));
        break;

      case SortMode.pointsRemainingDesc:
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            title: '${widget.category} • ${stat.name}',
                            items: filtered,
                            foundById: widget.foundById,
                            onToggle: widget.onToggle,
                            isTripActive: widget.isTripActive,
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

  const ItemScreen({
    super.key,
    required this.title,
    required this.items,
    required this.foundById,
    required this.onToggle,
    required this.isTripActive,
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
            title: Text('${it.name}  (+${it.points})'),
            subtitle: it.subCategory.isEmpty ? null : Text(it.subCategory),
            secondary: Icon(
              resolveIcon(iconName: it.iconName, groupName: it.subCategory),
              size: 36,
            ),
            value: checked,

            onChanged: (v) async {
              if (!widget.isTripActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Start a trip first')),
                );
                return;
              }

              final newVal = v ?? false;

              setState(() {
                widget.foundById[it.itemId] = newVal;
              });

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

            Text(
              'Final Score: ${trip.percent.toStringAsFixed(1)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 20),

            // --- Trip Identity ---
            Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 1),
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: [
                _tableRow('Trip', trip.tripName),
                _tableRow('ID', trip.tripId),
                _tableRow(
                  'Route',
                  '${trip.startLocation} → ${trip.endLocation}',
                ),
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

                _tableRow('Start', _formatTime(trip.startTime)),
                _tableRow('End', _formatTime(trip.endTime)),

                _tableRow(
                  'Duration',
                  _formatDuration(trip.startTime, trip.endTime),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (trip.perfectRun)
              const Text(
                '⭐ PERFECT RUN ⭐',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),

            const SizedBox(height: 30),

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
