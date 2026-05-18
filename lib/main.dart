import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, HapticFeedback, SystemSound, SystemSoundType;
import 'package:shared_preferences/shared_preferences.dart';

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
  progressDesc,
  remainingDesc,
  pointsRemainingDesc,
}

String sortLabel(SortMode mode) {
  switch (mode) {
    case SortMode.az:
      return 'A–Z';
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
  if (p >= 0.85) return Colors.green;
  if (p >= 0.50) return Colors.orange;
  if (p > 0.0) return Colors.redAccent;
  return Colors.grey;
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
IconData resolveIcon({
  required String iconName,
  required String groupName,
}) {
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
  static const csvPath = 'assets/Car Trip List App V0.10.csv';

  List<TripItem> items = [];
  Map<String, bool> foundById = {};

  List<GroupStat> categoryStats = [];
  int totalScore = 0;
  int maxScore = 0;

  bool loading = true;
  String? error;

  SortMode sortMode = SortMode.az;

  // prevent repeating category-complete dialog
  final Set<String> _completedCategoriesShown = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
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

    _applySort(list);
    categoryStats = list;
  }

  Future<void> _toggleAndPersist(String id, bool value) async {
    foundById[id] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(foundById));
  }

  Future<void> _resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);

    setState(() {
      for (final k in foundById.keys.toList()) {
        foundById[k] = false;
      }
      _completedCategoriesShown.clear();
      _recomputeCategoryStats();
    });
  }

  void _checkAndCelebrateCompletedCategories() {
    for (final stat in categoryStats) {
      if (stat.complete && !_completedCategoriesShown.contains(stat.name)) {
        _completedCategoriesShown.add(stat.name);

        Future.delayed(const Duration(milliseconds: 350), () async {
          if (!mounted) return;

          // built-in "feel" (no extra packages)
          try {
            await HapticFeedback.mediumImpact();
            SystemSound.play(SystemSoundType.click);
          } catch (_) {}

          // big dialog
          // ignore: use_build_context_synchronously
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, size: 72, color: Color(0xFFFFC107)),
                    const SizedBox(height: 14),
                    const Text(
                      '🎉 Category Complete!',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      stat.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Score: ${stat.score}/${stat.maxScore}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Nice!'),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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

    final percentTotal = (maxScore == 0) ? 0.0 : (totalScore * 100.0 / maxScore);
    final threshold = winningThresholdPercent(DateTime.now());
    final isWinning = percentTotal >= threshold;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Trip Game'),
        actions: [
          IconButton(
            tooltip: 'Reset progress',
            icon: const Icon(Icons.refresh),
            onPressed: _resetProgress,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: Colors.blue.withOpacity(0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total Score: $totalScore / $maxScore  (${percentTotal.toStringAsFixed(1)}%)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                            .map((m) => DropdownMenuItem(value: m, child: Text(sortLabel(m))))
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
                    valueColor: AlwaysStoppedAnimation<Color>(_progressColor(percentTotal / 100.0)),
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
                          'You Won! ${dayName(DateTime.now())} target met (≥ ${threshold.toStringAsFixed(1)}%). Keep going!',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Today’s target: ≥ ${threshold.toStringAsFixed(1)}% (${dayName(DateTime.now())}).',
                    style: const TextStyle(color: Colors.black54),
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
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final filtered = items.where((it) => it.category == stat.name).toList();

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubCategoryScreen(
                            category: stat.name,
                            items: filtered,
                            foundById: foundById,
                            onToggle: _toggleAndPersist,
                            initialSortMode: sortMode,
                          ),
                        ),
                      );

                      setState(() {
                        _recomputeCategoryStats();
                      });

                      _checkAndCelebrateCompletedCategories();
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(
                              resolveIcon(iconName: stat.iconName, groupName: stat.name),
                              color: color,
                              size: 36
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stat.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: p,
                                    minHeight: 8,
                                    backgroundColor: Colors.black12,
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('${stat.found}/${stat.total} • $percent% • $remaining left'),
                                Text('Score: ${stat.score}/${stat.maxScore}',
                                    style: const TextStyle(color: Colors.black54)),
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
   SUBCATEGORY SCREEN
-------------------------- */

class SubCategoryScreen extends StatefulWidget {
  final String category;
  final List<TripItem> items;
  final Map<String, bool> foundById;
  final Future<void> Function(String, bool) onToggle;
  final SortMode initialSortMode;

  const SubCategoryScreen({
    super.key,
    required this.category,
    required this.items,
    required this.foundById,
    required this.onToggle,
    required this.initialSortMode,
  });

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  List<GroupStat> subStats = [];
  int categoryScore = 0;
  int categoryMaxScore = 0;
  late SortMode sortMode;

  final Set<String> _completedSubcategoriesShown = {};

  @override
  void initState() {
    super.initState();
    sortMode = widget.initialSortMode;
    _recomputeSubStats();
    _checkAndCelebrateCompletedSubcategories();
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

  void _checkAndCelebrateCompletedSubcategories() {
    for (final stat in subStats) {
      if (stat.complete && !_completedSubcategoriesShown.contains(stat.name)) {
        _completedSubcategoriesShown.add(stat.name);

        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✅ ${stat.name} completed!",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryPercent =
        (categoryMaxScore == 0) ? 0.0 : (categoryScore * 100.0 / categoryMaxScore);

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
                  .map((m) => DropdownMenuItem(value: m, child: Text(sortLabel(m))))
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
            color: Colors.blue.withOpacity(0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Category Score', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final filtered = widget.items.where((it) => it.subCategory == stat.name).toList();

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemScreen(
                            title: '${widget.category} • ${stat.name}',
                            items: filtered,
                            foundById: widget.foundById,
                            onToggle: widget.onToggle,
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
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(
                              resolveIcon(iconName: stat.iconName, groupName: stat.name),
                              color: color,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stat.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: p,
                                    minHeight: 8,
                                    backgroundColor: Colors.black12,
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('${stat.found}/${stat.total} • $percent% • $remaining left'),
                                Text('Score: ${stat.score}/${stat.maxScore}',
                                    style: const TextStyle(color: Colors.black54)),
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

  const ItemScreen({
    super.key,
    required this.title,
    required this.items,
    required this.foundById,
    required this.onToggle,
  });

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  bool hideDone = false;

  @override
  Widget build(BuildContext context) {
    final visible = hideDone
        ? widget.items.where((it) => widget.foundById[it.itemId] != true).toList()
        : widget.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Row(
            children: [
              const Text('Hide done'),
              Switch(
                value: hideDone,
                onChanged: (v) => setState(() => hideDone = v),
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