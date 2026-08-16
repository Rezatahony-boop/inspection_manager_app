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
// DATA MODEL
// =====================================================

class Inspection {
  final String id;
  final String date;
  final String agentCode;
  final String agentName;
  final String city;
  final int inspectionCount;
  final int problemCount;
  final String problems;
  final String notes;

  Inspection({
    required this.id,
    required this.date,
    required this.agentCode,
    required this.agentName,
    required this.city,
    required this.inspectionCount,
    required this.problemCount,
    required this.problems,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'agentCode': agentCode,
      'agentName': agentName,
      'city': city,
      'inspectionCount': inspectionCount,
      'problemCount': problemCount,
      'problems': problems,
      'notes': notes,
    };
  }

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      agentCode: json['agentCode']?.toString() ?? '',
      agentName: json['agentName']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      inspectionCount: int.tryParse(
            json['inspectionCount']?.toString() ?? '0',
          ) ??
          0,
      problemCount: int.tryParse(
            json['problemCount']?.toString() ?? '0',
          ) ??
          0,
      problems: json['problems']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

// =====================================================
// STORAGE
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
// LOGIN
// =====================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController passwordController =
      TextEditingController();

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
                textAlign: TextAlign.center,
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
// DASHBOARD
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
// NEW INSPECTION
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
  final inspectionCountController =
      TextEditingController(text: '1');
  final problemCountController =
      TextEditingController(text: '0');
  final problemsController = TextEditingController();
  final notesController = TextEditingController();

  bool saving = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    dateController.text =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
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
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: dateController.text.trim(),
      agentCode: agentCodeController.text.trim(),
      agentName: agentNameController.text.trim(),
      city: cityController.text.trim(),
      inspectionCount:
          int.tryParse(inspectionCountController.text) ?? 1,
      problemCount:
          int.tryParse(problemCountController.text) ?? 0,
      problems: problemsController.text.trim(),
      notes: notesController.text.trim(),
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
    inspectionCountController.dispose();
    problemCountController.dispose();
    problemsController.dispose();
    notesController.dispose();

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
              label: 'تاریخ',
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
              controller: inspectionCountController,
              label: 'تعداد بازرسی',
              icon: Icons.assignment,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: problemCountController,
              label: 'تعداد مشکلات',
              icon: Icons.warning,
              keyboardType: TextInputType.number,
            ),
            AppTextField(
              controller: problemsController,
              label: 'شرح مشکلات',
              icon: Icons.description,
              maxLines: 4,
            ),
            AppTextField(
              controller: notesController,
              label: 'توضیحات',
              icon: Icons.notes,
              maxLines: 3,
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
                  saving ? 'در حال ذخیره...' : 'ثبت بازرسی',
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
// TEXT FIELD
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
// ARCHIVE
// =====================================================

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  List<Inspection> inspections = [];
  bool loading = true;

  final searchController = TextEditingController();

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

  List<Inspection> get filtered {
    final search = searchController.text.trim();

    if (search.isEmpty) {
      return inspections;
    }

    return inspections.where((item) {
      return item.agentCode.contains(search) ||
          item.agentName.contains(search);
    }).toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'جستجو با کد یا نام عامل',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'موردی پیدا نشد',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final item = filtered[index];

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
                                  '${item.city.isEmpty ? 'بدون شهر' : item.city} - ${item.date}',
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
                                RepeatedInspectionsPage(
                              inspections: inspections,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.repeat),
                      label: const Text(
                        'بازرسی‌های تکراری',
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
// INSPECTION DETAILS
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
            value: inspection.agentName,
          ),
          InfoCard(
            title: 'شهر',
            value: inspection.city,
          ),
          InfoCard(
            title: 'تاریخ',
            value: inspection.date,
          ),
          InfoCard(
            title: 'تعداد بازرسی',
            value: inspection.inspectionCount.toString(),
          ),
          InfoCard(
            title: 'تعداد مشکلات',
            value: inspection.problemCount.toString(),
          ),
          InfoCard(
            title: 'شرح مشکلات',
            value: inspection.problems.isEmpty
                ? 'ثبت نشده'
                : inspection.problems,
          ),
          InfoCard(
            title: 'توضیحات',
            value: inspection.notes.isEmpty
                ? 'ثبت نشده'
                : inspection.notes,
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
// REPEATED INSPECTIONS
// =====================================================

class RepeatedInspectionsPage extends StatelessWidget {
  final List<Inspection> inspections;

  const RepeatedInspectionsPage({
    super.key,
    required this.inspections,
  });

  Map<String, List<Inspection>> get repeated {
    final Map<String, List<Inspection>> groups = {};

    for (final item in inspections) {
      if (item.agentCode.trim().isEmpty) continue;

      groups.putIfAbsent(item.agentCode, () => []);
      groups[item.agentCode]!.add(item);
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
                style: TextStyle(fontSize: 18),
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
                            'تعداد کدهای تکراری',
                            style: TextStyle(fontSize: 17),
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
                      final code = groups.keys.elementAt(index);
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

class RepeatedDatesPage extends StatelessWidget {
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
// DAILY PERFORMANCE
// =====================================================

class DailyPerformancePage extends StatelessWidget {
  const DailyPerformancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'ثبت عملکرد روزانه',
      message:
          'بخش ثبت عملکرد روزانه در مرحله بعد تکمیل می‌شود.',
      icon: Icons.today,
    );
  }
}

// =====================================================
// REPORTS
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
// SETTINGS
// =====================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'تنظیمات',
      message:
          'تنظیمات نام بازرس، رمز عبور و سایر موارد در مرحله بعد تکمیل می‌شود.',
      icon: Icons.settings,
    );
  }
}

// =====================================================
// SIMPLE PAGE
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
            mainAxisAlignment: MainAxisAlignment.center,
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
