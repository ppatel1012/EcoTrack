import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Month labels
  static const List<String> _monthNames = [
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

  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();

    // Default range = last 3 full months (including current)
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);

    _startDate = DateTime(
      currentMonthStart.year,
      currentMonthStart.month - 2,
      1,
    );
    // last day of current month
    _endDate = DateTime(currentMonthStart.year, currentMonthStart.month + 1, 0);
  }

  String _monthLabel(DateTime d) => '${_monthNames[d.month - 1]} ${d.year}';

  String _formatShortDate(DateTime d) =>
      '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final DateTime firstAllowed = DateTime(now.year - 5);

    // Clamp the initial range so it never exceeds today's date
    final DateTime initialEnd = _endDate.isAfter(now) ? now : _endDate;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstAllowed,
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: initialEnd),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
      });
    }
  }

  Widget buildBar(String month, int value, Color color) {
    // Clamp width scale so enormous values don’t blow out layout
    const double baseWidthPerUnit = 14.0;
    const double maxWidth = 220.0;
    final double barWidth = (value * baseWidthPerUnit).clamp(0.0, maxWidth);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Container(
                  height: 22,
                  width: barWidth,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$month ($value)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget buildStatCard({
    required String title,
    required String rangeLabel,
    required Map<String, int> data,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title\n$rangeLabel',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bars
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: data.entries
                  .map((e) => buildBar(e.key, e.value, color))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('You must be logged in to view progress.')),
      );
    }

    final String uid = user.uid;
    final completionsRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('activityCompletions');

    // ensure start-of-day and end-of-day boundaries
    final DateTime startOfDay = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final DateTime endOfDay = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      23,
      59,
      59,
      999,
    );

    final Timestamp startTs = Timestamp.fromDate(startOfDay);
    final Timestamp endTs = Timestamp.fromDate(endOfDay);

    // Build month buckets inside selected range
    final DateTime startMonth = DateTime(_startDate.year, _startDate.month, 1);
    final DateTime endMonth = DateTime(_endDate.year, _endDate.month, 1);

    final List<DateTime> monthStarts = [];
    DateTime cursor = startMonth;
    while (!cursor.isAfter(endMonth)) {
      monthStarts.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    final List<String> monthLabels = monthStarts
        .map((d) => _monthLabel(d))
        .toList();

    final String rangeLabel =
        '${_formatShortDate(_startDate)} – ${_formatShortDate(_endDate)}';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Your Progress',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: completionsRef
            .where('date', isGreaterThanOrEqualTo: startTs)
            .where('date', isLessThanOrEqualTo: endTs)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Always allow date range picker, even if no data
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildRangeHeader(rangeLabel),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Center(
                      child: Text(
                        'No completed activities in this date range.\nTry selecting a wider range!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // activityName -> { monthLabel -> count }
          final Map<String, Map<String, int>> activityMonthCounts = {};

          for (final doc in docs) {
            final data = doc.data();
            final Timestamp? ts = data['date'] as Timestamp?;
            if (ts == null) continue;

            final DateTime d = ts.toDate();
            final DateTime thisMonthStart = DateTime(d.year, d.month, 1);

            final int monthIndex = monthStarts.indexWhere(
              (m) =>
                  m.year == thisMonthStart.year &&
                  m.month == thisMonthStart.month,
            );
            if (monthIndex == -1) continue; // outside of current range

            final String label = monthLabels[monthIndex];
            final String activityName =
                (data['activityString'] ?? 'Unnamed Activity') as String;

            final monthMap = activityMonthCounts.putIfAbsent(
              activityName,
              () => {for (final ml in monthLabels) ml: 0},
            );

            monthMap[label] = (monthMap[label] ?? 0) + 1;
          }

          if (activityMonthCounts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildRangeHeader(rangeLabel),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Center(
                      child: Text(
                        'No completed activities in this date range.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Sort activities by total completions desc
          final activityEntries = activityMonthCounts.entries.toList()
            ..sort((a, b) {
              final int sumA = a.value.values.fold(
                0,
                (prev, val) => prev + val,
              );
              final int sumB = b.value.values.fold(
                0,
                (prev, val) => prev + val,
              );
              return sumB.compareTo(sumA);
            });

          final List<Color> colors = [
            Colors.green,
            Colors.blue,
            Colors.orange,
            Colors.purple,
            Colors.teal,
            Colors.redAccent,
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRangeHeader(rangeLabel),
                const SizedBox(height: 12),
                for (int i = 0; i < activityEntries.length; i++)
                  buildStatCard(
                    title: activityEntries[i].key,
                    rangeLabel: rangeLabel,
                    data: activityEntries[i].value,
                    color: colors[i % colors.length],
                    icon: Icons.eco_rounded,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRangeHeader(String rangeLabel) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selected range',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              Text(
                rangeLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.date_range),
          label: const Text('Change'),
        ),
      ],
    );
  }
}
