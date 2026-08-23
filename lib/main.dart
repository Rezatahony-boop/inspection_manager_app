import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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
// تاریخ شمسی
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

  final jNp = jDayNo ~/ 12053;
  var jDay = jDayNo % 12053;

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
// مدل مستند
// =====================================================

class EvidenceFile {
  final String path;
  final String type;
  final String name;

  EvidenceFile({
    required this.path,
    required this.type,
    required this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'type': type,
      'name': name,
    };
  }

  factory EvidenceFile.fromJson(Map<String, dynamic> json) {
    return EvidenceFile(
      path: json['path']?.toString() ?? '',
      type: json['type']?.toString() ?? 'file',
      name: json['name']?.toString() ?? '',
    );
  }
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
  final List<EvidenceFile> evidences;

  Inspection({
    required this.id,
    required this.date,
    required this.agentCode,
    required this.agentName,
    required this.city,
    required this.problems,
    required this.evidences,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'agentCode': agentCode,
      'agentName': agentName,
      'city': city,
      'problems': problems,
      'evidences': evidences.map((e) => e.toJson()).toList(),
    };
  }

  factory Inspection.fromJson(Map<String, dynamic> json) {
    final evidenceData = json['evidences'];

    List<EvidenceFile> evidenceList = [];

    if (evidenceData is List) {
      evidenceList = evidenceData
          .map(
            (item) => EvidenceFile.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return Inspection(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      agentCode: json['agentCode']?.toString() ?? '',
      agentName: json['agentName']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      problems: json['problems']?.toString() ?? '',
      evidences: evidenceList,
    );
  }

  Inspection copyWith({
    List<EvidenceFile>? evidences,
  }) {
    return Inspection(
      id: id,
      date: date,
      agentCode: agentCode,
      agentName: agentName,
      city: city,
      problems: problems,
      evidences: evidences ?? this.evidences,
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

  static Future<void> updateInspection(
    Inspection updated,
  ) async {
    final inspections = await getInspections();

    final index = inspections.indexWhere(
      (item) => item.id == updated.id,
    );

    if (index != -1) {
      inspections[index] = updated;
      await saveInspections(inspections);
    }
  }
}

// =====================================================
// پوشه مستندات
// =====================================================

Future<Directory> getEvidenceDirectory() async {
  final base = await getApplicationDocumentsDirectory();

  final directory = Directory(
    '${base.path}/inspection_evidence',
  );

  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  return directory;
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
  void dispose() {
    passwordController.dispose();
    super.dispose();
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
}// =====================================================
// تنظیمات
// =====================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

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
}// =====================================================
// بازرسی‌های تکراری - ماهانه
// =====================================================

class RepeatedInspectionsPage extends StatefulWidget {
  final List<Inspection> inspections;

  const RepeatedInspectionsPage({
    super.key,
    required this.inspections,
  });

  @override
  State<RepeatedInspectionsPage> createState() =>
      _RepeatedInspectionsPageState();
}

class _RepeatedInspectionsPageState
    extends State<RepeatedInspectionsPage> {
  String? selectedMonth;

  String normalizeDigits(String value) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const english = '0123456789';

    var result = value;

    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(persian[i], english[i]);
      result = result.replaceAll(arabic[i], english[i]);
    }

    return result;
  }

  String getMonth(String date) {
    final parts = date.trim().split('/');

    if (parts.length < 2) {
      return '';
    }

    final year = normalizeDigits(parts[0]);
    final month = normalizeDigits(parts[1]).padLeft(2, '0');

    return '$year/$month';
  }

  int monthSortKey(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year = int.tryParse(parts[0]) ?? 0;
    final monthNumber = int.tryParse(parts[1]) ?? 0;

    return year * 100 + monthNumber;
  }

  String persianMonthName(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return month;
    }

    final number = int.tryParse(
          normalizeDigits(parts[1]),
        ) ??
        0;

    const names = [
      '',
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];

    if (number >= 1 && number <= 12) {
      return '${names[number]} ${parts[0]}';
    }

    return month;
  }

  List<String> get months {
    final result = widget.inspections
        .map((item) => getMonth(item.date))
        .where((month) => month.isNotEmpty)
        .toSet()
        .toList();

    result.sort(
      (a, b) => monthSortKey(b).compareTo(
        monthSortKey(a),
      ),
    );

    return result;
  }

  Map<String, List<Inspection>> repeatedForMonth(
    String month,
  ) {
    final Map<String, List<Inspection>> groups = {};

    for (final item in widget.inspections) {
      if (getMonth(item.date) != month) {
        continue;
      }

      final code = item.agentCode.trim();

      if (code.isEmpty) {
        continue;
      }

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
    if (selectedMonth == null) {
      return _buildMonthList(context);
    }

    final groups = repeatedForMonth(
      selectedMonth!,
    );

    return _buildCodeList(
      context,
      groups,
      selectedMonth!,
    );
  }

  Widget _buildMonthList(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'بازرسی‌های تکراری',
        ),
      ),
      body: months.isEmpty
          ? const Center(
              child: Text(
                'هیچ بازرسی تکراری ثبت نشده است',
                style: TextStyle(fontSize: 17),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: months.length,
              itemBuilder: (context, index) {
                final month = months[index];
                final groups = repeatedForMonth(month);

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor:
                          Color(0xFFC9A227),
                      child: Icon(
                        Icons.repeat,
                        color: Colors.black,
                      ),
                    ),
                    title: Text(
                      persianMonthName(month),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${groups.length} عامل تکراری',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
                    onTap: () {
                      setState(() {
                        selectedMonth = month;
                      });
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCodeList(
    BuildContext context,
    Map<String, List<Inspection>> groups,
    String month,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تکراری‌های ${persianMonthName(month)}',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              selectedMonth = null;
            });
          },
        ),
      ),
      body: groups.isEmpty
          ? const Center(
              child: Text(
                'در این ماه بازرسی تکراری وجود ندارد',
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
                            'تعداد عوامل تکراری',
                            style: TextStyle(
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            groups.length.toString(),
                            style: const TextStyle(
                              color: Color(0xFFC9A227),
                              fontSize: 28,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final code =
                          groups.keys.elementAt(index);

                      final records = groups[code]!;

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.store,
                            color: Color(0xFFC9A227),
                          ),
                          title: Text(
                            code,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: Text(
                            '${records.length} بار در این ماه بازرسی شده',
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
                                  month: month,
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
// تاریخ‌های بازرسی تکراری یک عامل
// =====================================================

class RepeatedDatesPage extends StatelessWidget {
  final String code;
  final List<Inspection> records;
  final String month;

  const RepeatedDatesPage({
    super.key,
    required this.code,
    required this.records,
    required this.month,
  });

  String normalizeDigits(String value) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const english = '0123456789';

    var result = value;

    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(persian[i], english[i]);
      result = result.replaceAll(arabic[i], english[i]);
    }

    return result;
  }

  int dateSortKey(String date) {
    final parts = date.trim().split('/');

    if (parts.length < 3) {
      return 0;
    }

    final year =
        int.tryParse(normalizeDigits(parts[0])) ?? 0;
    final month =
        int.tryParse(normalizeDigits(parts[1])) ?? 0;
    final day =
        int.tryParse(normalizeDigits(parts[2])) ?? 0;

    return year * 10000 + month * 100 + day;
  }

  @override
  Widget build(BuildContext context) {
    final sortedRecords = [...records];

    sortedRecords.sort(
      (a, b) => dateSortKey(b.date).compareTo(
        dateSortKey(a.date),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('کد عامل: $code'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: const Color(0xFF101B2E),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Icon(
                    Icons.repeat,
                    size: 50,
                    color: Color(0xFFC9A227),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'بازرسی‌های تکراری',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC9A227),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ماه: $month',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تعداد بازرسی: ${records.length}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(
            sortedRecords.length,
            (index) {
              final item = sortedRecords[index];

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        const Color(0xFFC9A227),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    item.date,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text(
                    item.agentName.isEmpty
                        ? 'بدون نام عامل'
                        : item.agentName,
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
        ],
      ),
    );
  }
}

// =====================================================
// ثبت عملکرد روزانه
// =====================================================

class DailyPerformancePage
    extends StatelessWidget {
  const DailyPerformancePage({
    super.key,
  });

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
// آمار و گزارش‌ها
// =====================================================

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
  });

  @override
  State<ReportsPage> createState() =>
      _ReportsPageState();
}

class _ReportsPageState
    extends State<ReportsPage> {
  List<Inspection> inspections = [];

  bool isLoading = true;

  String selectedDate = '';

  String? selectedMonth;

  @override
  void initState() {
    super.initState();

    selectedDate =
        gregorianToJalali(DateTime.now());

    _loadInspections();
  }

  Future<void> _loadInspections() async {
    try {
      final data =
          await AppStorage.getInspections();

      if (!mounted) return;

      setState(() {
        inspections = data;
        isLoading = false;

        if (selectedMonth != null &&
            !_months.contains(selectedMonth)) {
          selectedMonth = null;
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        inspections = [];
        isLoading = false;
      });
    }
  }

  String _normalizeDigits(String value) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const english = '0123456789';

    var result = value;

    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(
        persian[i],
        english[i],
      );

      result = result.replaceAll(
        arabic[i],
        english[i],
      );
    }

    return result;
  }

  String _getMonth(String date) {
    final parts = date.trim().split('/');

    if (parts.length < 2) {
      return '';
    }

    return '${_normalizeDigits(parts[0])}/${_normalizeDigits(parts[1]).padLeft(2, '0')}';
  }

  int _monthSortKey(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year =
        int.tryParse(parts[0]) ?? 0;

    final monthNumber =
        int.tryParse(parts[1]) ?? 0;

    return year * 100 + monthNumber;
  }

  String _persianMonthName(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return month;
    }

    final number =
        int.tryParse(parts[1]) ?? 0;

    const names = [
      '',
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
    ];

    if (number >= 1 && number <= 12) {
      return '${names[number]} ${parts[0]}';
    }

    return month;
  }

  List<String> get _months {
    final result = inspections
        .map((item) => _getMonth(item.date))
        .where(
          (month) => month.isNotEmpty,
        )
        .toSet()
        .toList();

    result.sort(
      (a, b) => _monthSortKey(b)
          .compareTo(_monthSortKey(a)),
    );

    return result;
  }

  List<Inspection> _recordsForDate(
    String date,
  ) {
    return inspections
        .where(
          (item) =>
              item.date.trim() ==
              date.trim(),
        )
        .toList();
  }

  List<Inspection> _recordsForMonth(
    String month,
  ) {
    return inspections
        .where(
          (item) =>
              _getMonth(item.date) ==
              month,
        )
        .toList();
  }

  bool _hasProblem(Inspection item) {
    return item.problems.trim().isNotEmpty;
  }

  int _problemCount(
    List<Inspection> records,
  ) {
    return records.where(_hasProblem).length;
  }

  double _problemPercent(
    List<Inspection> records,
  ) {
    if (records.isEmpty) {
      return 0;
    }

    return (_problemCount(records) /
            records.length) *
        100;
  }

  Map<String, List<Inspection>>
      _repeatedGroups(String month) {
    final Map<String, List<Inspection>>
        groups = {};

    for (final item
        in _recordsForMonth(month)) {
      final code =
          item.agentCode.trim();

      if (code.isEmpty) {
        continue;
      }

      groups.putIfAbsent(
        code,
        () => [],
      ).add(item);
    }

    groups.removeWhere(
      (key, value) => value.length < 2,
    );

    return groups;
  }

  int _repeatedInspectionCount(
    String month,
  ) {
    final groups =
        _repeatedGroups(month);

    var total = 0;

    for (final records
        in groups.values) {
      total += records.length;
    }

    return total;
  }

  Map<String, List<Inspection>>
      _cityGroups(
    List<Inspection> records,
  ) {
    final Map<String, List<Inspection>>
        groups = {};

    for (final item in records) {
      final city = item.city.trim();

      if (city.isEmpty) {
        continue;
      }

      groups.putIfAbsent(
        city,
        () => [],
      ).add(item);
    }

    return groups;
  }

  Future<void> _selectDate() async {
    final picked =
        await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate:
          DateTime.now().add(
        const Duration(days: 365),
      ),
      helpText:
          'انتخاب تاریخ گزارش',
      cancelText: 'انصراف',
      confirmText: 'تأیید',
    );

    if (picked == null ||
        !mounted) {
      return;
    }

    setState(() {
      selectedDate =
          gregorianToJalali(picked);
    });
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final card = Card(
      color: const Color(0xFF101B2E),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFFC9A227),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style:
                  const TextStyle(
                color:
                    Color(0xFFC9A227),
                fontSize: 23,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      borderRadius:
          BorderRadius.circular(12),
      onTap: onTap,
      child: card,
    );
  }

  Widget _dailyReport() {
    final records =
        _recordsForDate(
      selectedDate,
    );

    final problems =
        _problemCount(records);

    final withoutProblems =
        records.length - problems;

    final percent =
        _problemPercent(records);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'گزارش روزانه',
          style: TextStyle(
            color:
                Color(0xFFC9A227),
            fontSize: 21,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color:
              const Color(0xFF101B2E),
          child: ListTile(
            leading: const Icon(
              Icons.calendar_month,
              color:
                  Color(0xFFC9A227),
            ),
            title:
                const Text(
              'تاریخ گزارش',
            ),
            subtitle:
                Text(selectedDate),
            trailing:
                const Icon(
              Icons.edit_calendar,
            ),
            onTap:
                _selectDate,
          ),
        ),
        _statCard(
          title:
              'تعداد بازرسی انجام‌شده',
          value:
              records.length.toString(),
          icon:
              Icons.assignment_turned_in,
        ),
        _statCard(
          title:
              'تعداد دارای مشکل',
          value:
              problems.toString(),
          icon:
              Icons.warning_amber_rounded,
        ),
        _statCard(
          title:
              'تعداد بدون مشکل',
          value:
              withoutProblems.toString(),
          icon:
              Icons.check_circle_outline,
        ),
        _statCard(
          title:
              'درصد دارای مشکل',
          value:
              '${percent.toStringAsFixed(1)}٪',
          icon:
              Icons.percent,
        ),
      ],
    );
  }  Widget _monthlyReport() {
    final months = _months;

    if (months.isEmpty) {
      return const SizedBox.shrink();
    }

    final month =
        selectedMonth ?? months.first;

    final records =
        _recordsForMonth(month);

    final problems =
        _problemCount(records);

    final withoutProblems =
        records.length - problems;

    final percent =
        _problemPercent(records);

    final repeated =
        _repeatedInspectionCount(month);

    final repeatedGroups =
        _repeatedGroups(month);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        const Text(
          'گزارش ماهانه',
          style: TextStyle(
            color: Color(0xFFC9A227),
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        Card(
          color: const Color(0xFF101B2E),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
            ),
            child:
                DropdownButtonHideUnderline(
              child:
                  DropdownButton<String>(
                value: month,
                isExpanded: true,
                dropdownColor:
                    const Color(0xFF101B2E),
                items: months.map(
                  (item) {
                    return DropdownMenuItem<
                        String>(
                      value: item,
                      child: Text(
                        _persianMonthName(
                          item,
                        ),
                      ),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    selectedMonth =
                        value;
                  });
                },
              ),
            ),
          ),
        ),

        _statCard(
          title:
              'کل بازرسی‌های ماه',
          value:
              records.length.toString(),
          icon:
              Icons.assignment_turned_in,
        ),

        _statCard(
          title:
              'کل مشکلات ماه',
          value:
              problems.toString(),
          icon:
              Icons.warning_amber_rounded,
        ),

        _statCard(
          title:
              'بازرسی‌های بدون مشکل',
          value:
              withoutProblems.toString(),
          icon:
              Icons.check_circle_outline,
        ),

        _statCard(
          title:
              'درصد مشکلات',
          value:
              '${percent.toStringAsFixed(1)}٪',
          icon:
              Icons.percent,
        ),

        _statCard(
          title:
              'تعداد بازرسی‌های تکراری',
          value:
              repeated.toString(),
          icon:
              Icons.repeat,
          onTap: repeated == 0
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RepeatedInspectionsPage(
                        inspections:
                            inspections,
                      ),
                    ),
                  );
                },
        ),

        if (repeatedGroups.isNotEmpty) ...[
          const SizedBox(height: 8),

          Card(
            color:
                const Color(0xFF101B2E),
            child: Padding(
              padding:
                  const EdgeInsets.all(14),
              child: Text(
                '${repeatedGroups.length} کد عامل در این ماه حداقل ۲ بار بازرسی شده‌اند.',
                style:
                    const TextStyle(
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // =====================================================
  // آمار شهرها
  // =====================================================

  Widget _cityReport() {
    final records =
        selectedMonth == null
            ? inspections
            : _recordsForMonth(
                selectedMonth!,
              );

    final groups =
        _cityGroups(records);

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    final cities =
        groups.keys.toList();

    cities.sort(
      (a, b) =>
          groups[b]!.length.compareTo(
        groups[a]!.length,
      ),
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        const Text(
          'آمار شهرها',
          style: TextStyle(
            color: Color(0xFFC9A227),
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        ...cities.map(
          (city) {
            final cityRecords =
                groups[city]!;

            final problems =
                _problemCount(
              cityRecords,
            );

            final percent =
                _problemPercent(
              cityRecords,
            );

            return Card(
              color:
                  const Color(0xFF101B2E),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_city,
                          color:
                              Color(0xFFC9A227),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Expanded(
                          child: Text(
                            city,
                            style:
                                const TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    Text(
                      'تعداد بازرسی: ${cityRecords.length}',
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'تعداد مشکلات: $problems',
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'درصد مشکل: ${percent.toStringAsFixed(1)}٪',
                      style:
                          const TextStyle(
                        color:
                            Color(0xFFC9A227),
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // =====================================================
  // صفحه اصلی آمار و گزارش‌ها
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'آمار و گزارش‌ها',
        ),
      ),

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh:
                  _loadInspections,

              child: ListView(
                padding:
                    const EdgeInsets.all(
                  16,
                ),

                children: [
                  if (inspections.isEmpty)
                    const Card(
                      color:
                          Color(0xFF101B2E),

                      child: Padding(
                        padding:
                            EdgeInsets.all(
                          24,
                        ),

                        child: Column(
                          children: [
                            Icon(
                              Icons.bar_chart,
                              size: 64,
                              color:
                                  Color(
                                0xFFC9A227,
                              ),
                            ),

                            SizedBox(
                              height: 12,
                            ),

                            Text(
                              'هنوز هیچ بازرسی‌ای ثبت نشده است.',
                              textAlign:
                                  TextAlign
                                      .center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _dailyReport(),
                    _monthlyReport(),
                    _cityReport(),
                  ],
                ],
              ),
            ),
    );
  }
}// =====================================================
// تنظیمات
// =====================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

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
}// =====================================================
// ابزارهای کمکی گزارش‌ها و بایگانی
// =====================================================

String normalizePersianDigits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const english = '0123456789';

  var result = value;

  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(persian[i], english[i]);
    result = result.replaceAll(arabic[i], english[i]);
  }

  return result;
}

String normalizeDate(String value) {
  final parts = value.trim().split('/');

  if (parts.length != 3) {
    return normalizePersianDigits(value.trim());
  }

  final year = normalizePersianDigits(parts[0]);
  final month =
      normalizePersianDigits(parts[1]).padLeft(2, '0');
  final day =
      normalizePersianDigits(parts[2]).padLeft(2, '0');

  return '$year/$month/$day';
}

String inspectionMonth(String date) {
  final normalized = normalizeDate(date);
  final parts = normalized.split('/');

  if (parts.length < 2) {
    return '';
  }

  return '${parts[0]}/${parts[1]}';
}

int inspectionDateSortKey(String date) {
  final normalized = normalizeDate(date);
  final parts = normalized.split('/');

  if (parts.length != 3) {
    return 0;
  }

  final year = int.tryParse(parts[0]) ?? 0;
  final month = int.tryParse(parts[1]) ?? 0;
  final day = int.tryParse(parts[2]) ?? 0;

  return (year * 10000) + (month * 100) + day;
}

String inspectionMonthTitle(String month) {
  final parts = month.split('/');

  if (parts.length != 2) {
    return month;
  }

  final year = parts[0];
  final monthNumber =
      int.tryParse(
        normalizePersianDigits(parts[1]),
      ) ??
      0;

  const names = [
    '',
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  if (monthNumber >= 1 &&
      monthNumber <= 12) {
    return '${names[monthNumber]} $year';
  }

  return month;
}// =====================================================
// جستجوی پیشرفته بایگانی
// =====================================================

class AdvancedArchiveSearchPage extends StatefulWidget {
  final List<Inspection> inspections;

  const AdvancedArchiveSearchPage({
    super.key,
    required this.inspections,
  });

  @override
  State<AdvancedArchiveSearchPage> createState() =>
      _AdvancedArchiveSearchPageState();
}

class _AdvancedArchiveSearchPageState
    extends State<AdvancedArchiveSearchPage> {
  final TextEditingController searchController =
      TextEditingController();

  DateTime? selectedDate;

  List<Inspection> get results {
    final query = normalizePersianDigits(
      searchController.text.trim(),
    );

    var data = widget.inspections;

    if (selectedDate != null) {
      final jalaliDate =
          gregorianToJalali(selectedDate!);

      data = data.where((item) {
        return normalizeDate(item.date) ==
            normalizeDate(jalaliDate);
      }).toList();
    }

    if (query.isNotEmpty) {
      data = data.where((item) {
        final code = normalizePersianDigits(
          item.agentCode,
        );

        final name = item.agentName.trim();
        final city = item.city.trim();

        return code.contains(query) ||
            name.contains(searchController.text.trim()) ||
            city.contains(searchController.text.trim());
      }).toList();
    }

    data = [...data];

    data.sort(
      (a, b) => inspectionDateSortKey(
        b.date,
      ).compareTo(
        inspectionDateSortKey(
          a.date,
        ),
      ),
    );

    return data;
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      helpText: 'انتخاب تاریخ',
      cancelText: 'انصراف',
      confirmText: 'تأیید',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedDate = picked;
    });
  }

  void clearFilters() {
    setState(() {
      searchController.clear();
      selectedDate = null;
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = results;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'جستجوی بایگانی',
        ),
        actions: [
          IconButton(
            tooltip: 'پاک کردن فیلترها',
            icon: const Icon(
              Icons.clear_all,
            ),
            onPressed: clearFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration:
                      const InputDecoration(
                    labelText:
                        'کد عامل، نام عامل یا شهر',
                    prefixIcon:
                        Icon(Icons.search),
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: selectDate,
                    icon: const Icon(
                      Icons.calendar_month,
                    ),
                    label: Text(
                      selectedDate == null
                          ? 'جستجو بر اساس تاریخ'
                          : 'تاریخ انتخاب‌شده: ${gregorianToJalali(selectedDate!)}',
                    ),
                  ),
                ),

                if (selectedDate != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment:
                        Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedDate = null;
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                      ),
                      label: const Text(
                        'حذف تاریخ',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${data.length} نتیجه',
                style: const TextStyle(
                  color: Color(0xFFC9A227),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'موردی مطابق جستجو پیدا نشد.',
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: data.length,
                    itemBuilder:
                        (context, index) {
                      final item = data[index];

                      return Card(
                        child: ListTile(
                          leading:
                              const Icon(
                            Icons.assignment,
                            color:
                                Color(0xFFC9A227),
                          ),
                          title: Text(
                            item.agentCode,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${item.date}\n'
                            '${item.agentName.isEmpty ? 'بدون نام' : item.agentName} • '
                            '${item.city.isEmpty ? 'بدون شهر' : item.city}',
                          ),
                          isThreeLine: true,
                          trailing:
                              const Icon(
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
}// =====================================================
// بایگانی تاریخ‌محور
// =====================================================

class DateArchivePage extends StatefulWidget {
  final List<Inspection> inspections;

  const DateArchivePage({
    super.key,
    required this.inspections,
  });

  @override
  State<DateArchivePage> createState() =>
      _DateArchivePageState();
}

class _DateArchivePageState
    extends State<DateArchivePage> {
  String? selectedMonth;
  String? selectedDate;

  List<String> get months {
    final result = widget.inspections
        .map((item) => inspectionMonth(item.date))
        .where((month) => month.isNotEmpty)
        .toSet()
        .toList();

    result.sort(
      (a, b) => _monthSortKey(b)
          .compareTo(_monthSortKey(a)),
    );

    return result;
  }

  int _monthSortKey(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year = int.tryParse(
          normalizePersianDigits(parts[0]),
        ) ??
        0;

    final monthNumber = int.tryParse(
          normalizePersianDigits(parts[1]),
        ) ??
        0;

    return year * 100 + monthNumber;
  }

  List<String> get dates {
    if (selectedMonth == null) {
      return [];
    }

    final result = widget.inspections
        .where(
          (item) =>
              inspectionMonth(item.date) ==
              selectedMonth,
        )
        .map((item) => normalizeDate(item.date))
        .toSet()
        .toList();

    result.sort(
      (a, b) => inspectionDateSortKey(b)
          .compareTo(
            inspectionDateSortKey(a),
          ),
    );

    return result;
  }

  List<Inspection> recordsForDate(
    String date,
  ) {
    return widget.inspections
        .where(
          (item) =>
              normalizeDate(item.date) ==
              normalizeDate(date),
        )
        .toList();
  }

  int countForMonth(String month) {
    return widget.inspections
        .where(
          (item) =>
              inspectionMonth(item.date) ==
              month,
        )
        .length;
  }

  Widget monthList() {
    if (months.isEmpty) {
      return const Center(
        child: Text(
          'هنوز هیچ بازرسی‌ای ثبت نشده است.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: months.length,
      itemBuilder: (context, index) {
        final month = months[index];

        return Card(
          child: ListTile(
            leading: const Icon(
              Icons.folder,
              color: Color(0xFFC9A227),
              size: 32,
            ),
            title: Text(
              inspectionMonthTitle(month),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${countForMonth(month)} بازرسی',
            ),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () {
              setState(() {
                selectedMonth = month;
                selectedDate = null;
              });
            },
          ),
        );
      },
    );
  }

  Widget dateList() {
    if (dates.isEmpty) {
      return const Center(
        child: Text(
          'در این ماه بازرسی‌ای ثبت نشده است.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final records = recordsForDate(date);

        return Card(
          child: ListTile(
            leading: const Icon(
              Icons.calendar_month,
              color: Color(0xFFC9A227),
              size: 30,
            ),
            title: Text(
              date,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${records.length} بازرسی',
            ),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () {
              setState(() {
                selectedDate = date;
              });
            },
          ),
        );
      },
    );
  }

  Widget inspectionList() {
    final records = recordsForDate(
      selectedDate!,
    );

    if (records.isEmpty) {
      return const Center(
        child: Text(
          'بازرسی‌ای برای این تاریخ پیدا نشد.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final item = records[index];

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
              '${item.agentName.isEmpty ? 'بدون نام عامل' : item.agentName}\n'
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
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = 'بایگانی بر اساس تاریخ';

    if (selectedDate != null) {
      title = 'بازرسی‌های $selectedDate';
    } else if (selectedMonth != null) {
      title =
          inspectionMonthTitle(selectedMonth!);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: (selectedDate != null ||
                selectedMonth != null)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                ),
                onPressed: () {
                  setState(() {
                    if (selectedDate != null) {
                      selectedDate = null;
                    } else {
                      selectedMonth = null;
                    }
                  });
                },
              )
            : null,
      ),
      body: selectedDate != null
          ? inspectionList()
          : selectedMonth != null
              ? dateList()
              : monthList(),
    );
  }
}// =====================================================
// انتخاب تاریخ برای جستجوی سریع بایگانی
// =====================================================

class ArchiveDateSearchPage extends StatefulWidget {
  final List<Inspection> inspections;

  const ArchiveDateSearchPage({
    super.key,
    required this.inspections,
  });

  @override
  State<ArchiveDateSearchPage> createState() =>
      _ArchiveDateSearchPageState();
}

class _ArchiveDateSearchPageState
    extends State<ArchiveDateSearchPage> {
  final TextEditingController dateController =
      TextEditingController();

  List<Inspection> get results {
    final query = normalizeDate(
      dateController.text.trim(),
    );

    if (query.isEmpty ||
        dateController.text.trim().isEmpty) {
      return [];
    }

    final data = widget.inspections
        .where(
          (item) =>
              normalizeDate(item.date) == query,
        )
        .toList();

    data.sort(
      (a, b) => inspectionDateSortKey(b.date)
          .compareTo(
            inspectionDateSortKey(a.date),
          ),
    );

    return data;
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      helpText: 'انتخاب تاریخ بازرسی',
      cancelText: 'انصراف',
      confirmText: 'تأیید',
    );

    if (picked == null) {
      return;
    }

    final jalaliDate =
        gregorianToJalali(picked);

    setState(() {
      dateController.text = jalaliDate;
    });
  }

  void clearDate() {
    setState(() {
      dateController.clear();
    });
  }

  @override
  void dispose() {
    dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = results;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'جستجوی تاریخ',
        ),
        actions: [
          IconButton(
            tooltip: 'پاک کردن',
            icon: const Icon(
              Icons.clear_all,
            ),
            onPressed: clearDate,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: dateController,
                  textDirection: TextDirection.rtl,
                  keyboardType:
                      TextInputType.datetime,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration:
                      const InputDecoration(
                    labelText:
                        'تاریخ شمسی',
                    hintText:
                        'مثلاً ۱۴۰۵/۰۵/۰۲',
                    prefixIcon:
                        Icon(Icons.calendar_month),
                    border:
                        OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: selectDate,
                    icon: const Icon(
                      Icons.date_range,
                    ),
                    label: const Text(
                      'انتخاب از تقویم',
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (dateController.text.trim().isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Align(
                alignment:
                    Alignment.centerRight,
                child: Text(
                  '${data.length} بازرسی پیدا شد',
                  style: const TextStyle(
                    color:
                        Color(0xFFC9A227),
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          Expanded(
            child: data.isEmpty
                ? const Center(
                    child: Text(
                      'برای این تاریخ بازرسی‌ای پیدا نشد.',
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: data.length,
                    itemBuilder:
                        (context, index) {
                      final item =
                          data[index];

                      return Card(
                        child: ListTile(
                          leading:
                              const Icon(
                            Icons.assignment,
                            color:
                                Color(0xFFC9A227),
                          ),
                          title: Text(
                            item.agentCode,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          subtitle:
                              Text(
                            '${item.agentName.isEmpty ? 'بدون نام عامل' : item.agentName}\n'
                            '${item.city.isEmpty ? 'بدون شهر' : item.city}',
                          ),
                          isThreeLine: true,
                          trailing:
                              const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    InspectionDetailsPage(
                                  inspection:
                                      item,
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
}// =====================================================
// ابزار مرتب‌سازی و فیلتر پیشرفته گزارش‌ها
// =====================================================

class ReportFilterPage extends StatefulWidget {
  final List<Inspection> inspections;

  const ReportFilterPage({
    super.key,
    required this.inspections,
  });

  @override
  State<ReportFilterPage> createState() =>
      _ReportFilterPageState();
}

class _ReportFilterPageState
    extends State<ReportFilterPage> {
  String? selectedMonth;
  String? selectedCity;
  bool onlyProblems = false;
  bool onlyRepeated = false;

  List<String> get months {
    final result = widget.inspections
        .map((item) => inspectionMonth(item.date))
        .where((month) => month.isNotEmpty)
        .toSet()
        .toList();

    result.sort(
      (a, b) => _monthSortKey(b)
          .compareTo(_monthSortKey(a)),
    );

    return result;
  }

  List<String> get cities {
    final result = widget.inspections
        .map((item) => item.city.trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList();

    result.sort();
    return result;
  }

  int _monthSortKey(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year = int.tryParse(
          normalizePersianDigits(parts[0]),
        ) ??
        0;

    final monthNumber = int.tryParse(
          normalizePersianDigits(parts[1]),
        ) ??
        0;

    return year * 100 + monthNumber;
  }

  bool hasProblem(Inspection item) {
    return item.problems.trim().isNotEmpty;
  }

  Set<String> repeatedCodes() {
    final Map<String, int> counts = {};

    for (final item in widget.inspections) {
      final code = item.agentCode.trim();

      if (code.isEmpty) {
        continue;
      }

      counts[code] =
          (counts[code] ?? 0) + 1;
    }

    return counts.entries
        .where((entry) => entry.value >= 2)
        .map((entry) => entry.key)
        .toSet();
  }

  List<Inspection> get filtered {
    var result =
        List<Inspection>.from(
      widget.inspections,
    );

    if (selectedMonth != null) {
      result = result.where((item) {
        return inspectionMonth(item.date) ==
            selectedMonth;
      }).toList();
    }

    if (selectedCity != null) {
      result = result.where((item) {
        return item.city.trim() ==
            selectedCity;
      }).toList();
    }

    if (onlyProblems) {
      result = result
          .where(hasProblem)
          .toList();
    }

    if (onlyRepeated) {
      final repeated = repeatedCodes();

      result = result.where((item) {
        return repeated.contains(
          item.agentCode.trim(),
        );
      }).toList();
    }

    result.sort(
      (a, b) => inspectionDateSortKey(
        b.date,
      ).compareTo(
        inspectionDateSortKey(
          a.date,
        ),
      ),
    );

    return result;
  }

  void clearFilters() {
    setState(() {
      selectedMonth = null;
      selectedCity = null;
      onlyProblems = false;
      onlyRepeated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'فیلتر گزارش‌ها',
        ),
        actions: [
          IconButton(
            tooltip: 'حذف فیلترها',
            icon: const Icon(
              Icons.clear_all,
            ),
            onPressed: clearFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  color: const Color(0xFF101B2E),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    child:
                        DropdownButtonHideUnderline(
                      child:
                          DropdownButton<String?>(
                        value: selectedMonth,
                        isExpanded: true,
                        dropdownColor:
                            const Color(
                          0xFF101B2E,
                        ),
                        hint: const Text(
                          'همه ماه‌ها',
                        ),
                        items: [
                          const DropdownMenuItem<
                              String?>(
                            value: null,
                            child: Text(
                              'همه ماه‌ها',
                            ),
                          ),
                          ...months.map(
                            (month) =>
                                DropdownMenuItem<
                                    String?>(
                              value: month,
                              child: Text(
                                inspectionMonthTitle(
                                  month,
                                ),
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedMonth =
                                value;
                          });
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Card(
                  color: const Color(0xFF101B2E),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                    ),
                    child:
                        DropdownButtonHideUnderline(
                      child:
                          DropdownButton<String?>(
                        value: selectedCity,
                        isExpanded: true,
                        dropdownColor:
                            const Color(
                          0xFF101B2E,
                        ),
                        hint: const Text(
                          'همه شهرها',
                        ),
                        items: [
                          const DropdownMenuItem<
                              String?>(
                            value: null,
                            child: Text(
                              'همه شهرها',
                            ),
                          ),
                          ...cities.map(
                            (city) =>
                                DropdownMenuItem<
                                    String?>(
                              value: city,
                              child: Text(city),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCity =
                                value;
                          });
                        },
                      ),
                    ),
                  ),
                ),

                CheckboxListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  title: const Text(
                    'فقط بازرسی‌های دارای مشکل',
                  ),
                  value: onlyProblems,
                  activeColor:
                      const Color(0xFFC9A227),
                  onChanged: (value) {
                    setState(() {
                      onlyProblems =
                          value ?? false;
                    });
                  },
                ),

                CheckboxListTile(
                  contentPadding:
                      EdgeInsets.zero,
                  title: const Text(
                    'فقط بازرسی‌های تکراری',
                  ),
                  value: onlyRepeated,
                  activeColor:
                      const Color(0xFFC9A227),
                  onChanged: (value) {
                    setState(() {
                      onlyRepeated =
                          value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
// =====================================================
// صفحه نمایش جزئیات فیلترهای بایگانی
// =====================================================

class FilteredInspectionDetailsPage extends StatelessWidget {
  final Inspection inspection;

  const FilteredInspectionDetailsPage({
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
            value: inspection.agentCode.isEmpty
                ? 'ثبت نشده'
                : inspection.agentCode,
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
            value: inspection.date.isEmpty
                ? 'ثبت نشده'
                : inspection.date,
          ),
          InfoCard(
            title: 'شرح مشکلات',
            value: inspection.problems.isEmpty
                ? 'ثبت نشده'
                : inspection.problems,
          ),
          const SizedBox(height: 10),
          EvidenceViewer(
            evidences: inspection.evidences,
          ),
        ],
      ),
    );
  }
}

// =====================================================
// پایان بخش فیلتر و جزئیات
// =====================================================
