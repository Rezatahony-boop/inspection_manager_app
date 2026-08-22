import 'package:flutter/material.dart';

void main() {
  runApp(const InspectionApp());
}

class InspectionApp extends StatelessWidget {
  const InspectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سامانه مدیریت بازرسی',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePage(),
      ),
    );
  }
}

// ============================================================
// مدل اطلاعات بازرسی
// ============================================================

class Inspection {
  final String inspector;
  final String agentCode;
  final String city;
  final int problems;
  final String date;

  const Inspection({
    required this.inspector,
    required this.agentCode,
    required this.city,
    required this.problems,
    required this.date,
  });
}

// اطلاعات نمونه
final List<Inspection> inspections = [
  const Inspection(
    inspector: 'رضا طاحونی',
    agentCode: '1001',
    city: 'کاشمر',
    problems: 2,
    date: '1405/05/01',
  ),
  const Inspection(
    inspector: 'رضا طاحونی',
    agentCode: '1002',
    city: 'کاشمر',
    problems: 1,
    date: '1405/05/05',
  ),
  const Inspection(
    inspector: 'رضا طاحونی',
    agentCode: '2001',
    city: 'خلیل‌آباد',
    problems: 4,
    date: '1405/05/08',
  ),
  const Inspection(
    inspector: 'رضا طاحونی',
    agentCode: '2002',
    city: 'خلیل‌آباد',
    problems: 2,
    date: '1405/05/12',
  ),
];

// ============================================================
// اعداد فارسی
// ============================================================

String faDigits(String text) {
  const english = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';

  for (int i = 0; i < 10; i++) {
    text = text.replaceAll(english[i], persian[i]);
  }

  return text;
}

// ============================================================
// تاریخ شمسی
// ============================================================

class JalaliDate {
  final int year;
  final int month;
  final int day;

  const JalaliDate(
    this.year,
    this.month,
    this.day,
  );

  @override
  String toString() {
    return '$year/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')}';
  }

  int compareTo(JalaliDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }

    if (month != other.month) {
      return month.compareTo(other.month);
    }

    return day.compareTo(other.day);
  }

  static JalaliDate parse(String value) {
    final parts = value.trim().split('/');

    if (parts.length != 3) {
      throw const FormatException(
        'فرمت تاریخ اشتباه است',
      );
    }

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    if (year < 1200 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      throw const FormatException(
        'تاریخ نامعتبر است',
      );
    }

    return JalaliDate(
      year,
      month,
      day,
    );
  }

  static JalaliDate today() {
    final now = DateTime.now();

    final result = _gregorianToJalali(
      now.year,
      now.month,
      now.day,
    );

    return JalaliDate(
      result[0],
      result[1],
      result[2],
    );
  }

  static List<int> _gregorianToJalali(
    int gy,
    int gm,
    int gd,
  ) {
    int gDay = gd;

    const monthDays = [
      31,
      28,
      31,
      30,
      31,
      30,
      31,
      31,
      30,
      31,
      30,
      31,
    ];

    for (int i = 0; i < gm - 1; i++) {
      gDay += monthDays[i];
    }

    final leap =
        (gy % 4 == 0 && gy % 100 != 0) ||
        (gy % 400 == 0);

    if (leap && gm > 2) {
      gDay++;
    }

    int jy = gy - 621;

    int jDay = gDay - 80;

    if (jDay <= 0) {
      jy--;

      final previousYear = gy - 1;

      final previousLeap =
          (previousYear % 4 == 0 &&
                  previousYear % 100 != 0) ||
              previousYear % 400 == 0;

      jDay += previousLeap ? 366 : 365;
    }

    int jm;
    int jd;

    if (jDay <= 186) {
      jm = ((jDay - 1) ~/ 31) + 1;
      jd = ((jDay - 1) % 31) + 1;
    } else {
      jm = ((jDay - 187) ~/ 30) + 7;
      jd = ((jDay - 187) % 30) + 1;
    }

    return [
      jy,
      jm,
      jd,
    ];
  }
}

String todayJalali() {
  return JalaliDate.today().toString();
}

// ============================================================
// صفحه اصلی
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardPage(),
      const AddInspectionPage(),
      const ArchivePage(),
      const StatisticsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سامانه مدیریت بازرسی',
        ),
        centerTitle: true,
      ),
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'ثبت بازرسی',
          ),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            selectedIcon: Icon(Icons.archive),
            label: 'بایگانی',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'آمار',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// داشبورد
// ============================================================

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final totalProblems = inspections.fold<int>(
      0,
      (sum, item) => sum + item.problems,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'سامانه مدیریت بازرسی',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'بازرس: رضا طاحونی',
                ),
                const SizedBox(height: 4),
                Text(
                  'تاریخ امروز: ${faDigits(todayJalali())}',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: SummaryCard(
                title: 'کل بازرسی',
                value: inspections.length,
                icon: Icons.assignment_turned_in,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SummaryCard(
                title: 'کل مشکلات',
                value: totalProblems,
                icon: Icons.warning_amber,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        MenuTile(
          icon: Icons.add,
          title: 'ثبت بازرسی جدید',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const AddInspectionPage(),
              ),
            );
          },
        ),

        MenuTile(
          icon: Icons.archive,
          title: 'بایگانی بازرسی‌ها',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const ArchivePage(),
              ),
            );
          },
        ),

        MenuTile(
          icon: Icons.bar_chart,
          title:
              'آمار، بازه زمانی، مقایسه شهرها و نمودار',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const StatisticsPage(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
            ),
            const SizedBox(height: 6),
            Text(title),
            const SizedBox(height: 4),
            Text(
              faDigits(
                value.toString(),
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(
          Icons.chevron_left,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ============================================================
// ثبت بازرسی
// ============================================================

class AddInspectionPage extends StatefulWidget {
  const AddInspectionPage({super.key});

  @override
  State<AddInspectionPage> createState() =>
      _AddInspectionPageState();
}

class _AddInspectionPageState
    extends State<AddInspectionPage> {
  final codeController =
      TextEditingController();

  final problemsController =
      TextEditingController();

  final cityController =
      TextEditingController();

  String date = todayJalali();

  @override
  void dispose() {
    codeController.dispose();
    problemsController.dispose();
    cityController.dispose();

    super.dispose();
  }

  void saveInspection() {
    if (codeController.text.trim().isEmpty ||
        cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'کد عامل و شهر را وارد کنید.',
          ),
        ),
      );

      return;
    }

    final problemCount =
        int.tryParse(
              problemsController.text.trim(),
            ) ??
            0;

    inspections.add(
      Inspection(
        inspector: 'رضا طاحونی',
        agentCode:
            codeController.text.trim(),
        city: cityController.text.trim(),
        problems: problemCount,
        date: date,
      ),
    );

    setState(() {
      codeController.clear();
      problemsController.clear();
      cityController.clear();

      date = todayJalali();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'بازرسی با موفقیت ثبت شد.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ثبت بازرسی جدید',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: codeController,
            keyboardType:
                TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'کد عامل',
              border:
                  OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller:
                problemsController,
            keyboardType:
                TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'تعداد مشکلات',
              border:
                  OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: cityController,
            decoration: const InputDecoration(
              labelText: 'شهر',
              border:
                  OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.calendar_month,
              ),
              title: const Text(
                'تاریخ بازرسی',
              ),
              subtitle: Text(
                faDigits(date),
              ),
            ),
          ),

          const SizedBox(height: 15),

          FilledButton.icon(
            onPressed: saveInspection,
            icon: const Icon(
              Icons.save,
            ),
            label: const Text(
              'ثبت بازرسی',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// بایگانی
// ============================================================

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() =>
      _ArchivePageState();
}

class _ArchivePageState
    extends State<ArchivePage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final results =
        inspections.where((item) {
      return item.agentCode.contains(
            query,
          ) ||
          item.city.contains(
            query,
          ) ||
          item.date.contains(
            query,
          );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'بایگانی بازرسی‌ها',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  query = value;
                });
              },
              decoration:
                  const InputDecoration(
                hintText:
                    'جستجو با کد عامل، شهر یا تاریخ شمسی',
                prefixIcon:
                    Icon(Icons.search),
                border:
                    OutlineInputBorder(),
              ),
            ),
          ),

          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text(
                      'موردی پیدا نشد.',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        results.length,
                    itemBuilder:
                        (_, index) {
                      final item =
                          results[index];

                      return Card(
                        margin:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child: ListTile(
                          leading:
                              CircleAvatar(
                            child: Text(
                              faDigits(
                                item.problems
                                    .toString(),
                              ),
                            ),
                          ),
                          title: Text(
                            'عامل ${item.agentCode} - ${item.city}',
                          ),
                          subtitle:
                              Text(
                            'تاریخ: ${faDigits(item.date)}\n'
                            'تعداد مشکلات: ${faDigits(item.problems.toString())}',
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

// ============================================================
// صفحه آمار
// ============================================================

class StatisticsPage
    extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() =>
      _StatisticsPageState();
}

class _StatisticsPageState
    extends State<StatisticsPage> {
  late TextEditingController
      fromController;

  late TextEditingController
      toController;

  String fromDate = '1405/01/01';

  late String toDate;

  String city1 = 'کاشمر';
  String city2 = 'خلیل‌آباد';

  @override
  void initState() {
    super.initState();

    toDate = todayJalali();

    fromController =
        TextEditingController(
      text: fromDate,
    );

    toController =
        TextEditingController(
      text: toDate,
    );
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();

    super.dispose();
  }

  List<String> get cities {
    final Set<String> result =
        <String>{};

    for (final item in inspections) {
      result.add(item.city);
    }

    return result.toList()..sort();
  }

  List<Inspection> get filteredData {
    try {
      final from =
          JalaliDate.parse(
        fromDate,
      );

      final to =
          JalaliDate.parse(
        toDate,
      );

      return inspections.where(
        (item) {
          final date =
              JalaliDate.parse(
            item.date,
          );

          return date.compareTo(
                    from,
                  ) >=
                  0 &&
              date.compareTo(
                    to,
                  ) <=
                  0;
        },
      ).toList();
    } catch (_) {
      return [];
    }
  }

  int cityInspectionCount(
    List<Inspection> data,
    String city,
  ) {
    return data
        .where(
          (item) => item.city == city,
        )
        .length;
  }

  int cityProblemCount(
    List<Inspection> data,
    String city,
  ) {
    return data
        .where(
          (item) => item.city == city,
        )
        .fold<int>(
          0,
          (sum, item) =>
              sum + item.problems,
        );
  }

  void applyDateRange() {
    try {
      final from =
          JalaliDate.parse(
        fromController.text.trim(),
      );

      final to =
          JalaliDate.parse(
        toController.text.trim(),
      );

      if (from.compareTo(to) > 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'تاریخ شروع نمی‌تواند بعد از تاریخ پایان باشد.',
            ),
          ),
        );

        return;
      }

      setState(() {
        fromDate = from.toString();
        toDate = to.toString();
      });
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'فرمت تاریخ باید مثل 1405/05/25 باشد.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final data = filteredData;

    final totalInspections =
        data.length;

    final totalProblems =
        data.fold<int>(
      0,
      (sum, item) =>
          sum + item.problems,
    );

    final problemPercent =
        totalInspections == 0
            ? 0
            : (totalProblems *
                    100 /
                    totalInspections)
                .round();

    final city1Inspections =
        cityInspectionCount(
      data,
      city1,
    );

    final city2Inspections =
        cityInspectionCount(
      data,
      city2,
    );

    final city1Problems =
        cityProblemCount(
      data,
      city1,
    );

    final city2Problems =
        cityProblemCount(
      data,
      city2,
    );

    final city1Percent =
        city1Inspections == 0
            ? 0
            : (city1Problems *
                    100 /
                    city1Inspections)
                .round();

    final city2Percent =
        city2Inspections == 0
            ? 0
            : (city2Problems *
                    100 /
                    city2Inspections)
                .round();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'آمار و نمودار',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(14),
        children: [
          const SectionTitle(
            '۱. آمار بین دو تاریخ',
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller:
                      fromController,
                  textDirection:
                      TextDirection.ltr,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'از تاریخ شمسی',
                    hintText:
                        '1405/01/01',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: TextField(
                  controller:
                      toController,
                  textDirection:
                      TextDirection.ltr,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'تا تاریخ شمسی',
                    hintText:
                        '1405/12/29',
                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          FilledButton.icon(
            onPressed:
                applyDateRange,
            icon: const Icon(
              Icons.filter_alt,
            ),
            label: const Text(
              'اعمال بازه زمانی',
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'بازه فعال: ${faDigits(fromDate)} تا ${faDigits(toDate)}',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'بازرسی',
                  value:
                      totalInspections,
                  icon:
                      Icons.assignment,
                ),
              ),

              const SizedBox(width: 7),

              Expanded(
                child: StatCard(
                  title: 'مشکل',
                  value:
                      totalProblems,
                  icon:
                      Icons.warning,
                ),
              ),

              const SizedBox(width: 7),

              Expanded(
                child: StatCard(
                  title: 'درصد مشکل',
                  value:
                      problemPercent,
                  suffix: '%',
                  icon:
                      Icons.percent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          const SectionTitle(
            '۲. مقایسه دو شهر',
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: cityDropdown(
                  'شهر اول',
                  city1,
                  (value) {
                    if (value != null) {
                      setState(() {
                        city1 = value;
                      });
                    }
                  },
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: cityDropdown(
                  'شهر دوم',
                  city2,
                  (value) {
                    if (value != null) {
                      setState(() {
                        city2 = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(15),
              child: Column(
                children: [
                  CompareRow(
                    title:
                        'تعداد بازرسی',
                    firstCity:
                        city1,
                    firstValue:
                        city1Inspections,
                    secondCity:
                        city2,
                    secondValue:
                        city2Inspections,
                  ),

                  const Divider(),

                  CompareRow(
                    title:
                        'تعداد مشکلات',
                    firstCity:
                        city1,
                    firstValue:
                        city1Problems,
                    secondCity:
                        city2,
                    secondValue:
                        city2Problems,
                  ),

                  const Divider(),

                  CompareRow(
                    title:
                        'درصد مشکل',
                    firstCity:
                        city1,
                    firstValue:
                        city1Percent,
                    secondCity:
                        city2,
                    secondValue:
                        city2Percent,
                    suffix: '%',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 25),

          const SectionTitle(
            '۳. نمودارها',
          ),

          const SizedBox(height: 10),

          ComparisonChart(
            title:
                'مقایسه تعداد بازرسی دو شهر',
            firstCity:
                city1,
            firstValue:
                city1Inspections,
            secondCity:
                city2,
            secondValue:
                city2Inspections,
          ),

          const SizedBox(height: 12),

          ComparisonChart(
            title:
                'مقایسه تعداد مشکلات دو شهر',
            firstCity:
                city1,
            firstValue:
                city1Problems,
            secondCity:
                city2,
            secondValue:
                city2Problems,
          ),

          const SizedBox(height: 12),

          DailyChart(
            data: data,
          ),
        ],
      ),
    );
  }

  Widget cityDropdown(
    String label,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    final items =
        cities.isEmpty
            ? [value]
            : cities;

    final selected =
        items.contains(value)
            ? value
            : items.first;

    return DropdownButtonFormField<
        String>(
      value: selected,
      decoration:
          InputDecoration(
        labelText: label,
        border:
            const OutlineInputBorder(),
      ),
      items: items
          .map(
            (city) =>
                DropdownMenuItem(
              value: city,
              child: Text(city),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ============================================================
// عنوان بخش
// ============================================================

class SectionTitle
    extends StatelessWidget {
  final String text;

  const SectionTitle(
    this.text, {
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      text,
      style:
          const TextStyle(
        fontSize: 19,
        fontWeight:
            FontWeight.bold,
      ),
    );
  }
}

// ============================================================
// کارت آمار
// ============================================================

class StatCard
    extends StatelessWidget {
  final String title;
  final int value;
  final String suffix;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.suffix = '',
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 4,
        ),
        child: Column(
          children: [
            Icon(icon),

            const SizedBox(
              height: 5,
            ),

            Text(title),

            const SizedBox(
              height: 3,
            ),

            Text(
              '${faDigits(value.toString())}$suffix',
              style:
                  const TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// جدول مقایسه
// ============================================================

class CompareRow
    extends StatelessWidget {
  final String title;

  final String firstCity;
  final int firstValue;

  final String secondCity;
  final int secondValue;

  final String suffix;

  const CompareRow({
    super.key,
    required this.title,
    required this.firstCity,
    required this.firstValue,
    required this.secondCity,
    required this.secondValue,
    this.suffix = '',
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$firstCity: ${faDigits(firstValue.toString())}$suffix',
            textAlign:
                TextAlign.center,
          ),
        ),

        Expanded(
          child: Text(
            title,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),

        Expanded(
          child: Text(
            '$secondCity: ${faDigits(secondValue.toString())}$suffix',
            textAlign:
                TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// نمودار میله‌ای
// ============================================================

class ComparisonChart
    extends StatelessWidget {
  final String title;

  final String firstCity;
  final int firstValue;

  final String secondCity;
  final int secondValue;

  const ComparisonChart({
    super.key,
    required this.title,
    required this.firstCity,
    required this.firstValue,
    required this.secondCity,
    required this.secondValue,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final maxValue =
        [
          firstValue,
          secondValue,
          1,
        ].reduce(
          (a, b) =>
              a > b ? a : b,
        );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            buildBar(
              context,
              firstCity,
              firstValue,
              maxValue,
            ),

            const SizedBox(
              height: 15,
            ),

            buildBar(
              context,
              secondCity,
              secondValue,
              maxValue,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBar(
    BuildContext context,
    String city,
    int value,
    int maxValue,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween,
          children: [
            Text(city),
            Text(
              faDigits(
                value.toString(),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 5,
        ),

        ClipRRect(
          borderRadius:
              BorderRadius.circular(
            7,
          ),
          child:
              LinearProgressIndicator(
            value:
                value / maxValue,
            minHeight: 22,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// نمودار روزانه
// ============================================================

class DailyChart
    extends StatelessWidget {
  final List<Inspection> data;

  const DailyChart({
    super.key,
    required this.data,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final Map<String, int>
        dailyCounts = {};

    for (final item in data) {
      dailyCounts[item.date] =
          (dailyCounts[item.date] ??
                  0) +
              1;
    }

    final entries =
        dailyCounts.entries.toList()
          ..sort(
            (a, b) {
              return JalaliDate.parse(
                a.key,
              ).compareTo(
                JalaliDate.parse(
                  b.key,
                ),
              );
            },
          );

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding:
              EdgeInsets.all(18),
          child: Text(
            'در بازه انتخاب‌شده داده‌ای برای نمایش نمودار وجود ندارد.',
          ),
        ),
      );
    }

    final maxValue =
        entries
            .map(
              (e) => e.value,
            )
            .fold<int>(
              1,
              (a, b) =>
                  a > b ? a : b,
            );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'روند تعداد بازرسی‌ها بر اساس تاریخ',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .end,
                children:
                    entries.map(
                  (entry) {
                    final height =
                        145.0 *
                            entry.value /
                            maxValue;

                    return Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 3,
                        ),
                        child:
                            Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .end,
                          children: [
                            Text(
                              faDigits(
                                entry.value
                                    .toString(),
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Container(
                              height:
                                  height.clamp(
                                5.0,
                                145.0,
                              ),
                              decoration:
                                  BoxDecoration(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  5,
                                ),
                                color: Theme.of(
                                  context,
                                )
                                    .colorScheme
                                    .primary,
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            Text(
                              faDigits(
                                entry.key,
                              ),
                              textAlign:
                                  TextAlign
                                      .center,
                              style:
                                  const TextStyle(
                                fontSize:
                                    9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
