import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const InspectionManagerApp());
}

class InspectionManagerApp extends StatelessWidget {
  const InspectionManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سامانه مدیریت بازرسی',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC9A227),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF08111F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF08111F),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// =====================================================
// تبدیل تاریخ میلادی به شمسی
// =====================================================

String toPersianDigits(String text) {
  const english = '0123456789';
  const persian = '۰۱۲۳۴۵۶۷۸۹';

  for (int i = 0; i < english.length; i++) {
    text = text.replaceAll(english[i], persian[i]);
  }

  return text;
}

String gregorianToJalali(DateTime date) {
  int gy = date.year;
  int gm = date.month;
  int gd = date.day;

  int jy;
  int jm;
  int jd;

  final gDayNo = _gregorianDayNumber(gy, gm, gd);

  final jDayNo = gDayNo - _gregorianDayNumber(1600, 3, 21);

  int jNp = jDayNo ~/ 12053;
  int jDay = jDayNo % 12053;

  jy = 979 + 33 * jNp + 4 * (jDay ~/ 1461);
  jDay %= 1461;

  if (jDay >= 366) {
    jy += (jDay - 1) ~/ 365;
    jDay = (jDay - 1) % 365;
  }

  if (jDay < 186) {
    jm = 1 + jDay ~/ 31;
    jd = 1 + jDay % 31;
  } else {
    jm = 7 + (jDay - 186) ~/ 30;
    jd = 1 + (jDay - 186) % 30;
  }

  return toPersianDigits(
    '$jy/${jm.toString().padLeft(2, '0')}/${jd.toString().padLeft(2, '0')}',
  );
}

int _gregorianDayNumber(int gy, int gm, int gd) {
  final gy2 = gy + ((gm > 2) ? 1 : 0);

  return (365 * gy) +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      gd +
      _gregorianMonthDays(gm, gy);
}

int _gregorianMonthDays(int gm, int gy) {
  const mdays = [
    0,
    0,
    31,
    59,
    90,
    120,
    151,
    181,
    212,
    243,
    273,
    304,
    334,
  ];

  int result = mdays[gm];

  if (gm > 2 && _isGregorianLeap(gy)) {
    result++;
  }

  return result;
}

bool _isGregorianLeap(int year) {
  return year % 4 == 0 &&
      (year % 100 != 0 || year % 400 == 0);
}

// =====================================================
// مدل بازرسی
// =====================================================

class Inspection {
  final String id;
  final String date;
  final String agentCode;
  final String agentName;
  final String city;
  final String problems;

  Inspection({
    required this.id,
    required this.date,
    required this.agentCode,
    required this.agentName,
    required this.city,
    required this.problems,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'agentCode': agentCode,
      'agentName': agentName,
      'city': city,
      'problems': problems,
    };
  }

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      agentCode: json['agentCode']?.toString() ?? '',
      agentName: json['agentName']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      problems: json['problems']?.toString() ?? '',
    );
  }
}

// =====================================================
// ذخیره اطلاعات
// =====================================================

class AppStorage {
  static const String inspectionsKey = 'inspections';

  static Future<List<Inspection>> getInspections() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(inspectionsKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(data);

      return decoded
          .map(
            (item) => Inspection.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveInspections(
    List<Inspection> inspections,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final data = inspections
        .map((inspection) => inspection.toJson())
        .toList();

    await prefs.setString(
      inspectionsKey,
      jsonEncode(data),
    );
  }

  static Future<void> addInspection(
    Inspection inspection,
  ) async {
    final inspections = await getInspections();

    inspections.insert(0, inspection);

    await saveInspections(inspections);
  }
}

// =====================================================
// ورود
// =====================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final passwordController = TextEditingController();

  void login() {
    if (passwordController.text == '1234') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardPage(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رمز عبور اشتباه است'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user,
                size: 82,
                color: Color(0xFFC9A227),
              ),
              const SizedBox(height: 20),
              const Text(
                'سامانه مدیریت بازرسی',
                style: TextStyle(
                  color: Color(0xFFC9A227),
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: passwordController,
                obscureText: true,
                onSubmitted: (_) => login(),
                decoration: const InputDecoration(
                  labelText: 'رمز ورود',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: login,
                  child: const Text(
                    'ورود به برنامه',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// داشبورد
// =====================================================

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('داشبورد'),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: [
          DashboardButton(
            title: 'ثبت بازرسی جدید',
            icon: Icons.assignment_add,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NewInspectionPage(),
                ),
              );
            },
          ),
          DashboardButton(
            title: 'ثبت عملکرد روزانه',
            icon: Icons.today,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DailyPerformancePage(),
                ),
              );
            },
          ),
          DashboardButton(
            title: 'بایگانی',
            icon: Icons.folder,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ArchivePage(),
                ),
              );
            },
          ),
          DashboardButton(
            title: 'گزارش‌ها',
            icon: Icons.bar_chart,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportsPage(),
                ),
              );
            },
          ),
          DashboardButton(
            title: 'تنظیمات',
            icon: Icons.settings,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class DashboardButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF101B2E),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 46,
              color: const Color(0xFFC9A227),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// ثبت بازرسی جدید
// =====================================================

class NewInspectionPage extends StatefulWidget {
  const NewInspectionPage({super.key});

  @override
  State<NewInspectionPage> createState() =>
      _NewInspectionPageState();
}

class _NewInspectionPageState
    extends State<NewInspectionPage> {
  final dateController = TextEditingController();
  final agentCodeController = TextEditingController();
  final agentNameController = TextEditingController();
  final cityController = TextEditingController();
  final problemsController = TextEditingController();

  bool saving = false;

  @override
  void initState() {
    super.initState();

    dateController.text =
        gregorianToJalali(DateTime.now());
  }

  Future<void> save() async {
    if (agentCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('کد عامل را وارد کنید'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    final inspection = Inspection(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
      date: dateController.text.trim(),
      agentCode: agentCodeController.text.trim(),
      agentName: agentNameController.text.trim(),
      city: cityController.text.trim(),
      problems: problemsController.text.trim(),
    );

    await AppStorage.addInspection(inspection);

    if (!mounted) return;

    setState(() {
      saving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('بازرسی با موفقیت ثبت شد'),
      ),
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    dateController.dispose();
    agentCodeController.dispose();
    agentNameController.dispose();
    cityController.dispose();
    problemsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ثبت بازرسی جدید'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppTextField(
              controller: dateController,
              label: 'تاریخ شمسی',
              icon: Icons.calendar_month,
            ),
            AppTextField(
              controller: agentCodeController,
              label: 'کد عامل *',
              icon: Icons.numbers,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: agentNameController,
              label: 'نام عامل',
              icon: Icons.store,
            ),
            AppTextField(
              controller: cityController,
              label: 'شهر',
              icon: Icons.location_city,
            ),
            AppTextField(
              controller: problemsController,
              label: 'شرح مشکلات',
              icon: Icons.warning,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  saving
                      ? 'در حال ذخیره...'
                      : 'ثبت بازرسی',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// فیلد
// =====================================================

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

// =====================================================
// بایگانی - ابتدا تاریخ‌ها
// =====================================================

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() =>
      _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<Inspection> inspections = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await AppStorage.getInspections();

    if (!mounted) return;

    setState(() {
      inspections = data;
      loading = false;
    });
  }

  List<String> get dates {
    final result = inspections
        .map((item) => item.date)
        .where((date) => date.isNotEmpty)
        .toSet()
        .toList();

    result.sort((a, b) => b.compareTo(a));

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بایگانی'),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : dates.isEmpty
              ? const Center(
                  child: Text(
                    'هنوز هیچ بازرسی ثبت نشده است',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    final date = dates[index];

                    final count = inspections
                        .where(
                          (item) => item.date == date,
                        )
                        .length;

                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.calendar_month,
                          color: Color(0xFFC9A227),
                        ),
                        title: Text(
                          date,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '$count بازرسی',
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DailyArchivePage(
                                date: date,
                                inspections: inspections,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// =====================================================
// بازرسی‌های یک روز
// =====================================================

class DailyArchivePage extends StatefulWidget {
  final String date;
  final List<Inspection> inspections;

  const DailyArchivePage({
    super.key,
    required this.date,
    required this.inspections,
  });

  @override
  State<DailyArchivePage> createState() =>
      _DailyArchivePageState();
}

class _DailyArchivePageState
    extends State<DailyArchivePage> {
  final searchController = TextEditingController();

  List<Inspection> get dailyInspections {
    var result = widget.inspections
        .where(
          (item) => item.date == widget.date,
        )
        .toList();

    final search = searchController.text.trim();

    if (search.isNotEmpty) {
      result = result.where((item) {
        return item.agentCode.contains(search) ||
            item.agentName.contains(search);
      }).toList();
    }

    return result;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = dailyInspections;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.date),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'جستجوی کد یا نام عامل',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'بازرسی‌ای برای این تاریخ پیدا نشد',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor:
                                Color(0xFFC9A227),
                            child: Icon(
                              Icons.assignment,
                              color: Colors.black,
                            ),
                          ),
                          title: Text(
                            item.agentCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${item.agentName.isEmpty ? 'بدون نام' : item.agentName}\n'
                            '${item.city.isEmpty ? 'بدون شهر' : item.city}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InspectionDetailsPage(
                                  inspection: item,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SearchArchivePage(
                        inspections:
                            widget.inspections,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.manage_search),
                label: const Text(
                  'جستجوی پیشرفته بایگانی',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// جزئیات
// =====================================================

class InspectionDetailsPage extends StatelessWidget {
  final Inspection inspection;

  const InspectionDetailsPage({
    super.key,
    required this.inspection,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات بازرسی'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            title: 'کد عامل',
            value: inspection.agentCode,
          ),
          InfoCard(
            title: 'نام عامل',
            value: inspection.agentName.isEmpty
                ? 'ثبت نشده'
                : inspection.agentName,
          ),
          InfoCard(
            title: 'شهر',
            value: inspection.city.isEmpty
                ? 'ثبت نشده'
                : inspection.city,
          ),
          InfoCard(
            title: 'تاریخ',
            value: inspection.date,
          ),
          InfoCard(
            title: 'شرح مشکلات',
            value: inspection.problems.isEmpty
                ? 'ثبت نشده'
                : inspection.problems,
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFC9A227),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(value),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// جستجوی پیشرفته
// =====================================================

class SearchArchivePage extends StatefulWidget {
  final List<Inspection> inspections;

  const SearchArchivePage({
    super.key,
    required this.inspections,
  });

  @override
  State<SearchArchivePage> createState() =>
      _SearchArchivePageState();
}

class _SearchArchivePageState
    extends State<SearchArchivePage> {
  final codeController = TextEditingController();

  List<Inspection> get results {
    final code = codeController.text.trim();

    if (code.isEmpty) {
      return [];
    }

    return widget.inspections
        .where(
          (item) => item.agentCode.contains(code),
        )
        .toList();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = results;

    return Scaffold(
      appBar: AppBar(
        title: const Text('جستجوی بایگانی'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: codeController,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'کد عامل',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'کدی پیدا نشد',
                    ),
                  )
                : ListView.builder(
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];

                      return Card(
                        child: ListTile(
                          title: Text(
                            item.agentCode,
                          ),
                          subtitle: Text(
                            '${item.date} - ${item.city}',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InspectionDetailsPage(
                                  inspection: item,
                                ),
                              ),
                            );
                          },
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

// =====================================================
// بازرسی‌های تکراری
// =====================================================

class RepeatedInspectionsPage
    extends StatelessWidget {
  final List<Inspection> inspections;

  const RepeatedInspectionsPage({
    super.key,
    required this.inspections,
  });

  Map<String, List<Inspection>> get repeated {
    final Map<String, List<Inspection>> groups = {};

    for (final item in inspections) {
      final code = item.agentCode.trim();

      if (code.isEmpty) continue;

      groups.putIfAbsent(code, () => []);
      groups[code]!.add(item);
    }

    groups.removeWhere(
      (key, value) => value.length < 2,
    );

    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = repeated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بازرسی‌های تکراری'),
      ),
      body: groups.isEmpty
          ? const Center(
              child: Text(
                'بازرسی تکراری ثبت نشده است',
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: const Color(0xFF101B2E),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'تعداد موارد تکراری',
                            style: TextStyle(
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            groups.length.toString(),
                            style: const TextStyle(
                              color: Color(0xFFC9A227),
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final code =
                          groups.keys.elementAt(index);

                      final records = groups[code]!;

                      return Card(
                        child: ListTile(
                          title: Text(
                            code,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${records.length} بار بازرسی شده',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RepeatedDatesPage(
                                  code: code,
                                  records: records,
                                ),
                              ),
                            );
                          },
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

class RepeatedDatesPage
    extends StatelessWidget {
  final String code;
  final List<Inspection> records;

  const RepeatedDatesPage({
    super.key,
    required this.code,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('کد عامل: $code'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final item = records[index];

          return Card(
            child: ListTile(
              leading: const Icon(
                Icons.calendar_month,
                color: Color(0xFFC9A227),
              ),
              title: Text(item.date),
              subtitle: Text(
                item.agentName.isEmpty
                    ? 'بدون نام عامل'
                    : item.agentName,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        InspectionDetailsPage(
                      inspection: item,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// =====================================================
// عملکرد روزانه
// =====================================================

class DailyPerformancePage
    extends StatelessWidget {
  const DailyPerformancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'ثبت عملکرد روزانه',
      message:
          'این بخش در مرحله بعد تکمیل می‌شود.',
      icon: Icons.today,
    );
  }
}

// =====================================================
// گزارش‌ها
// =====================================================

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'گزارش‌ها',
      message:
          'گزارش‌های روزانه، ماهانه و مقایسه شهرها در مرحله بعد تکمیل می‌شود.',
      icon: Icons.bar_chart,
    );
  }
}

// =====================================================
// تنظیمات
// =====================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'تنظیمات',
      message:
          'تنظیمات بازرس و رمز عبور در مرحله بعد تکمیل می‌شود.',
      icon: Icons.settings,
    );
  }
}

// =====================================================
// صفحه ساده
// =====================================================

class SimplePage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const SimplePage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 80,
                color: const Color(0xFFC9A227),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC9A227),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
