import 'dart:convert';
import 'dart:io';

import 'package:docx_dart/docx_dart.dart' as docx;
import 'package:excel/excel.dart';
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


String normalizeDigitsGlobal(String value) {
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

String normalizeJalaliDate(String value) {
  final parts = value.trim().split('/');
  if (parts.length != 3) return value.trim();

  final y = normalizeDigitsGlobal(parts[0]).padLeft(4, '0');
  final m = normalizeDigitsGlobal(parts[1]).padLeft(2, '0');
  final d = normalizeDigitsGlobal(parts[2]).padLeft(2, '0');
  return '$y/$m/$d';
}

int jalaliDateKey(String value) {
  final normalized = normalizeJalaliDate(value);
  final parts = normalized.split('/');
  if (parts.length != 3) return 0;

  final y = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final d = int.tryParse(parts[2]) ?? 0;

  return (y * 10000) + (m * 100) + d;
}

bool isValidJalaliDate(String value) {
  final normalized = normalizeJalaliDate(value);
  final parts = normalized.split('/');
  if (parts.length != 3) return false;

  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);

  if (y == null || m == null || d == null) return false;
  return y >= 1300 && y <= 1500 && m >= 1 && m <= 12 && d >= 1 && d <= 31;
}

Future<String?> showJalaliDateDialog(
  BuildContext context, {
  required String initialDate,
  String title = 'انتخاب تاریخ شمسی',
}) async {
  final controller = TextEditingController(
    text: normalizeJalaliDate(initialDate),
  );

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.datetime,
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: 'تاریخ شمسی',
            hintText: '۱۴۰۵/۰۵/۲۳',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_month),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!isValidJalaliDate(value)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تاریخ را به شکل ۱۴۰۵/۰۵/۲۳ وارد کنید.'),
                  ),
                );
                return;
              }
              Navigator.pop(
                dialogContext,
                normalizeJalaliDate(value),
              );
            },
            child: const Text('تأیید'),
          ),
        ],
      );
    },
  );

  controller.dispose();
  return result;
}

String formatJalaliDate(String value) {
  final normalized = normalizeJalaliDate(value);
  final parts = normalized.split('/');
  if (parts.length != 3) return toPersianDigits(value);
  return toPersianDigits(normalized);
}

String jalaliMonthTitle(String month) {
  final parts = normalizeDigitsGlobal(month).split('/');
  if (parts.length != 2) return toPersianDigits(month);

  final monthNumber = int.tryParse(parts[1]) ?? 0;
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

  if (monthNumber < 1 || monthNumber > 12) {
    return toPersianDigits(month);
  }

  return '${names[monthNumber]} ${toPersianDigits(parts[0])}';
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
      'evidences':
          evidences.map((e) => e.toJson()).toList(),
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

  static Future<void> deleteInspection(String id) async {
    final inspections = await getInspections();
    inspections.removeWhere((item) => item.id == id);
    await saveInspections(inspections);
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
// ثبت بازرسی
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

  final ImagePicker imagePicker = ImagePicker();
  final AudioRecorder audioRecorder = AudioRecorder();

  final List<EvidenceFile> evidences = [];

  bool saving = false;
  bool recording = false;
  String? recordingPath;

  @override
  void initState() {
    super.initState();

    dateController.text =
        gregorianToJalali(DateTime.now());
  }

  // ---------------------------------------------------
  // عکس از گالری
  // ---------------------------------------------------

  Future<void> pickGalleryImages() async {
    try {
      final images =
          await imagePicker.pickMultiImage(
        imageQuality: 90,
      );

      if (images.isEmpty) return;

      final directory =
          await getEvidenceDirectory();

      for (final image in images) {
        final extension =
            image.path.split('.').last;

        final fileName =
            'photo_${DateTime.now().millisecondsSinceEpoch}_'
            '${evidences.length}.$extension';

        final destination = File(
          '${directory.path}/$fileName',
        );

        await File(image.path).copy(
          destination.path,
        );

        evidences.add(
          EvidenceFile(
            path: destination.path,
            type: 'image',
            name: fileName,
          ),
        );
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      showMessage('خطا در انتخاب عکس');
    }
  }

  // ---------------------------------------------------
  // دوربین
  // ---------------------------------------------------

  Future<void> takePhoto() async {
    try {
      final image = await imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image == null) return;

      final directory =
          await getEvidenceDirectory();

      final extension =
          image.path.split('.').last;

      final fileName =
          'camera_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final destination = File(
        '${directory.path}/$fileName',
      );

      await File(image.path).copy(
        destination.path,
      );

      evidences.add(
        EvidenceFile(
          path: destination.path,
          type: 'image',
          name: fileName,
        ),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      showMessage('خطا در گرفتن عکس');
    }
  }

  // ---------------------------------------------------
  // فایل
  // ---------------------------------------------------

  Future<void> pickFile() async {
    try {
      final result =
          await FilePicker.platform.pickFiles();

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final picked = result.files.first;

      if (picked.path == null) {
        showMessage('فایل قابل دسترسی نیست');
        return;
      }

      final directory =
          await getEvidenceDirectory();

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_'
          '${picked.name}';

      final destination = File(
        '${directory.path}/$fileName',
      );

      await File(picked.path!).copy(
        destination.path,
      );

      evidences.add(
        EvidenceFile(
          path: destination.path,
          type: 'file',
          name: picked.name,
        ),
      );

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      showMessage('خطا در انتخاب فایل');
    }
  }

  // ---------------------------------------------------
  // ضبط وویس
  // ---------------------------------------------------

  Future<void> startRecording() async {
    try {
      final hasPermission =
          await audioRecorder.hasPermission();

      if (!hasPermission) {
        showMessage(
          'اجازه استفاده از میکروفون داده نشد',
        );
        return;
      }

      final directory =
          await getEvidenceDirectory();

      recordingPath =
          '${directory.path}/voice_'
          '${DateTime.now().millisecondsSinceEpoch}.m4a';

      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: recordingPath!,
      );

      if (!mounted) return;
      setState(() {
        recording = true;
      });
    } catch (_) {
      showMessage('خطا در شروع ضبط صدا');
    }
  }

  Future<void> stopRecording() async {
    try {
      final path = await audioRecorder.stop();

      if (mounted) {
        setState(() {
          recording = false;
        });
      }

      if (path != null && path.isNotEmpty) {
        final file = EvidenceFile(
          path: path,
          type: 'audio',
          name: 'فایل صوتی',
        );

        evidences.add(file);

        if (mounted) {
          setState(() {});
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          recording = false;
        });
      }

      showMessage('خطا در ذخیره فایل صوتی');
    }
  }

  // ---------------------------------------------------
  // حذف مستند
  // ---------------------------------------------------

  Future<void> removeEvidence(
    int index,
  ) async {
    final evidence = evidences[index];

    try {
      final file = File(evidence.path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    setState(() {
      evidences.removeAt(index);
    });
  }

  // ---------------------------------------------------
  // پیام
  // ---------------------------------------------------

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ---------------------------------------------------
  // ذخیره بازرسی
  // ---------------------------------------------------

  Future<void> save() async {
    if (agentCodeController.text.trim().isEmpty) {
      showMessage('کد عامل را وارد کنید');
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
      evidences: List<EvidenceFile>.from(evidences),
    );

    await AppStorage.addInspection(inspection);

    if (!mounted) return;

    setState(() {
      saving = false;
    });

    showMessage(
      'بازرسی و مستندات با موفقیت ثبت شد',
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    if (recording) {
      audioRecorder.stop();
    }

    audioRecorder.dispose();

    dateController.dispose();
    agentCodeController.dispose();
    agentNameController.dispose();
    cityController.dispose();
    problemsController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------
  // کارت مستندات
  // ---------------------------------------------------

  Widget evidenceSection() {
    return Card(
      color: const Color(0xFF101B2E),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: Color(0xFFC9A227),
                ),
                SizedBox(width: 8),
                Text(
                  'ثبت مستندات',
                  style: TextStyle(
                    color: Color(0xFFC9A227),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pickGalleryImages,
                    icon: const Icon(Icons.photo),
                    label: const Text('گالری'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('دوربین'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        recording
                            ? stopRecording
                            : startRecording,
                    icon: Icon(
                      recording
                          ? Icons.stop
                          : Icons.mic,
                    ),
                    label: Text(
                      recording
                          ? 'پایان ضبط'
                          : 'ضبط وویس',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pickFile,
                    icon: const Icon(
                      Icons.insert_drive_file,
                    ),
                    label: const Text('فایل'),
                  ),
                ),
              ],
            ),

            if (recording) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    color: Colors.red,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'در حال ضبط صدا...',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            if (evidences.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const Text(
                'مستندات اضافه‌شده:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              ...List.generate(
                evidences.length,
                (index) {
                  final evidence =
                      evidences[index];

                  IconData icon;

                  if (evidence.type == 'image') {
                    icon = Icons.image;
                  } else if (evidence.type == 'audio') {
                    icon = Icons.audiotrack;
                  } else {
                    icon = Icons.insert_drive_file;
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      icon,
                      color:
                          const Color(0xFFC9A227),
                    ),
                    title: Text(
                      evidence.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () =>
                          removeEvidence(index),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
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
              keyboardType:
                  TextInputType.number,
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

            evidenceSection(),

            const SizedBox(height: 4),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    saving ? null : save,
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
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
      padding:
          const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border:
              const OutlineInputBorder(),
        ),
      ),
    );
  }
}

// =====================================================
// بایگانی
// =====================================================

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
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
    try {
      final data = await AppStorage.getInspections();
      if (!mounted) return;
      setState(() {
        inspections = data;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        inspections = [];
        loading = false;
      });
    }
  }

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
    if (parts.length < 2) return '';
    final year = normalizeDigits(parts[0]);
    final month = normalizeDigits(parts[1]).padLeft(2, '0');
    if (year.isEmpty || month.isEmpty) return '';
    return '$year/$month';
  }

  int monthSortKey(String month) {
    final parts = month.split('/');
    if (parts.length != 2) return 0;
    final year = int.tryParse(parts[0]) ?? 0;
    final monthNumber = int.tryParse(parts[1]) ?? 0;
    return (year * 100) + monthNumber;
  }

  String monthTitle(String month) {
    final parts = month.split('/');
    if (parts.length != 2) return month;
    final year = parts[0];
    final monthNumber = int.tryParse(parts[1]) ?? 0;
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
    if (monthNumber >= 1 && monthNumber <= 12) {
      return '${names[monthNumber]} $year';
    }
    return month;
  }

  List<String> get months {
    final result = inspections
        .map((item) => getMonth(item.date))
        .where((month) => month.isNotEmpty)
        .toSet()
        .toList();
    result.sort(
      (a, b) => monthSortKey(b).compareTo(monthSortKey(a)),
    );
    return result;
  }

  int countForMonth(String month) {
    return inspections.where(
      (item) => getMonth(item.date) == month,
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بایگانی'),
        actions: [
          IconButton(
            tooltip: 'بازرسی‌های تکراری',
            icon: const Icon(Icons.repeat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RepeatedInspectionsPage(
                    inspections: inspections,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'جستجو',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchArchivePage(
                    inspections: inspections,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : months.isEmpty
              ? const Center(
                  child: Text(
                    'هنوز هیچ بازرسی ثبت نشده است',
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final month = months[index];
                    final count = countForMonth(month);
                    return Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.folder,
                          color: Color(0xFFC9A227),
                          size: 32,
                        ),
                        title: Text(
                          monthTitle(month),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text('$count بازرسی'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MonthArchivePage(
                                month: month,
                                monthTitleText: monthTitle(month),
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
// بایگانی یک ماه
// =====================================================

class MonthArchivePage extends StatelessWidget {
  final String month;
  final String monthTitleText;
  final List<Inspection> inspections;

  const MonthArchivePage({
    super.key,
    required this.month,
    required this.monthTitleText,
    required this.inspections,
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

  String getMonth(String date) {
    final parts = date.trim().split('/');
    if (parts.length < 2) return '';
    return '${normalizeDigits(parts[0])}/${normalizeDigits(parts[1]).padLeft(2, '0')}';
  }

  String getDay(String date) {
    final parts = date.trim().split('/');
    if (parts.length < 3) return date;
    return normalizeDigits(parts[2]).padLeft(2, '0');
  }

  int daySortKey(String date) {
    final parts = date.split('/');
    if (parts.length < 3) return 0;
    final year = int.tryParse(parts[0]) ?? 0;
    final monthNumber = int.tryParse(parts[1]) ?? 0;
    final day = int.tryParse(parts[2]) ?? 0;
    return (year * 10000) + (monthNumber * 100) + day;
  }

  List<String> get dates {
    final result = inspections
        .where((item) => getMonth(item.date) == month)
        .map((item) => item.date)
        .where((date) => date.isNotEmpty)
        .toSet()
        .toList();
    result.sort(
      (a, b) => daySortKey(b).compareTo(daySortKey(a)),
    );
    return result;
  }

  int countForDate(String date) {
    return inspections.where((item) => item.date == date).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(monthTitleText)),
      body: dates.isEmpty
          ? const Center(
              child: Text('در این ماه بازرسی‌ای ثبت نشده است'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: dates.length,
              itemBuilder: (context, index) {
                final date = dates[index];
                final count = countForDate(date);
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_month,
                      color: Color(0xFFC9A227),
                      size: 30,
                    ),
                    title: Text(
                      'روز ${getDay(date)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('$date  •  $count بازرسی'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DailyArchivePage(
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

class DailyArchivePage
    extends StatefulWidget {
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
  final searchController =
      TextEditingController();

  List<Inspection> get dailyInspections {
    var result = widget.inspections
        .where(
          (item) =>
              item.date == widget.date,
        )
        .toList();

    final search =
        searchController.text.trim();

    if (search.isNotEmpty) {
      result = result.where((item) {
        return item.agentCode
                .contains(search) ||
            item.agentName
                .contains(search);
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
            padding:
                const EdgeInsets.all(16),
            child: TextField(
              controller:
                  searchController,
              onChanged: (_) =>
                  setState(() {}),
              decoration:
                  const InputDecoration(
                labelText:
                    'جستجوی کد یا نام عامل',
                prefixIcon:
                    Icon(Icons.search),
                border:
                    OutlineInputBorder(),
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
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount:
                        data.length,
                    itemBuilder:
                        (context, index) {
                      final item =
                          data[index];

                      return Card(
                        child: ListTile(
                          leading:
                              const CircleAvatar(
                            backgroundColor:
                                Color(
                              0xFFC9A227,
                            ),
                            child: Icon(
                              Icons.assignment,
                              color:
                                  Colors.black,
                            ),
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
                            '${item.agentName.isEmpty ? 'بدون نام' : item.agentName}\n'
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
}

// =====================================================
// جزئیات بازرسی
// =====================================================


class InspectionDetailsPage extends StatefulWidget {
  final Inspection inspection;

  const InspectionDetailsPage({
    super.key,
    required this.inspection,
  });

  @override
  State<InspectionDetailsPage> createState() =>
      _InspectionDetailsPageState();
}

class _InspectionDetailsPageState
    extends State<InspectionDetailsPage> {
  late Inspection currentInspection;

  @override
  void initState() {
    super.initState();
    currentInspection = widget.inspection;
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<Inspection>(
      context,
      MaterialPageRoute(
        builder: (_) => EditInspectionPage(
          inspection: currentInspection,
        ),
      ),
    );

    if (updated == null || !mounted) return;

    setState(() {
      currentInspection = updated;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف بازرسی'),
          content: const Text(
            'آیا از حذف این بازرسی مطمئن هستید؟ این عملیات قابل بازگشت نیست.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await AppStorage.deleteInspection(currentInspection.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('بازرسی با موفقیت حذف شد')),
    );

    Navigator.pop(context, true);
  }

  Widget _actionButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    bool danger = false,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: danger ? Colors.redAccent : const Color(0xFFC9A227),
        ),
        label: Text(title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inspection = currentInspection;

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
            value: formatJalaliDate(inspection.date),
          ),
          InfoCard(
            title: 'شرح مشکلات',
            value: inspection.problems.isEmpty
                ? 'ثبت نشده'
                : inspection.problems,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _actionButton(
                title: 'ویرایش',
                icon: Icons.edit,
                onPressed: _edit,
              ),
              const SizedBox(width: 10),
              _actionButton(
                title: 'حذف',
                icon: Icons.delete_outline,
                onPressed: _delete,
                danger: true,
              ),
            ],
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
// ویرایش بازرسی
// =====================================================

class EditInspectionPage extends StatefulWidget {
  final Inspection inspection;

  const EditInspectionPage({
    super.key,
    required this.inspection,
  });

  @override
  State<EditInspectionPage> createState() =>
      _EditInspectionPageState();
}

class _EditInspectionPageState
    extends State<EditInspectionPage> {
  late final TextEditingController dateController;
  late final TextEditingController agentCodeController;
  late final TextEditingController agentNameController;
  late final TextEditingController cityController;
  late final TextEditingController problemsController;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    final item = widget.inspection;

    dateController = TextEditingController(text: item.date);
    agentCodeController =
        TextEditingController(text: item.agentCode);
    agentNameController =
        TextEditingController(text: item.agentName);
    cityController =
        TextEditingController(text: item.city);
    problemsController =
        TextEditingController(text: item.problems);
  }

  Future<void> _selectDate() async {
    final selected = await showJalaliDateDialog(
      context,
      initialDate: dateController.text,
      title: 'تغییر تاریخ بازرسی',
    );

    if (selected != null && mounted) {
      setState(() {
        dateController.text = selected;
      });
    }
  }

  Future<void> _save() async {
    if (agentCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('کد عامل را وارد کنید')),
      );
      return;
    }

    final date = normalizeJalaliDate(dateController.text);
    if (!isValidJalaliDate(date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تاریخ را به شکل ۱۴۰۵/۰۵/۲۳ وارد کنید.'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    final updated = Inspection(
      id: widget.inspection.id,
      date: date,
      agentCode: agentCodeController.text.trim(),
      agentName: agentNameController.text.trim(),
      city: cityController.text.trim(),
      problems: problemsController.text.trim(),
      evidences: List<EvidenceFile>.from(
        widget.inspection.evidences,
      ),
    );

    await AppStorage.updateInspection(updated);

    if (!mounted) return;

    setState(() {
      saving = false;
    });

    Navigator.pop(context, updated);
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
        title: const Text('ویرایش بازرسی'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _selectDate,
              child: AbsorbPointer(
                child: AppTextField(
                  controller: dateController,
                  label: 'تاریخ شمسی',
                  icon: Icons.calendar_month,
                ),
              ),
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: saving ? null : _save,
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
                  saving ? 'در حال ذخیره...' : 'ذخیره تغییرات',
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
// نمایش مستندات
// =====================================================

class EvidenceViewer
    extends StatelessWidget {
  final List<EvidenceFile> evidences;

  const EvidenceViewer({
    super.key,
    required this.evidences,
  });

  @override
  Widget build(BuildContext context) {
    if (evidences.isEmpty) {
      return Card(
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Column(
            children: const [
              Icon(
                Icons.attach_file,
                size: 45,
                color:
                    Colors.white38,
              ),
              SizedBox(height: 8),
              Text(
                'برای این بازرسی مستندی ثبت نشده است',
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color:
          const Color(0xFF101B2E),
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.folder_special,
                  color:
                      Color(0xFFC9A227),
                ),
                SizedBox(width: 8),
                Text(
                  'مستندات ثبت‌شده',
                  style: TextStyle(
                    color:
                        Color(0xFFC9A227),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...evidences.map(
              (evidence) =>
                  EvidenceTile(
                evidence: evidence,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> openEvidence(
  BuildContext context,
  EvidenceFile evidence,
) async {
  final path = evidence.path.trim();

  if (path.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('مسیر مستند خالی است')),
    );
    return;
  }

  final file = File(path);

  try {
    if (!await file.exists()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'فایل مستند پیدا نشد. ممکن است فایل حذف یا جابه‌جا شده باشد.',
          ),
        ),
      );
      return;
    }

    if (evidence.type == 'image') {
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullImagePage(
            path: path,
            title: evidence.name,
          ),
        ),
      );
      return;
    }

    final result = await OpenFilex.open(path);

    if (!context.mounted) return;

    final message = result.message.trim();
    if (message.isNotEmpty &&
        !message.toLowerCase().contains('done')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('باز کردن فایل موفق نبود: $message'),
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'امکان باز کردن این مستند وجود ندارد. برنامه مناسب برای این نوع فایل را نصب کنید.',
        ),
      ),
    );
  }
}

class EvidenceTile extends StatelessWidget {
  final EvidenceFile evidence;

  const EvidenceTile({
    super.key,
    required this.evidence,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;

    if (evidence.type == 'image') {
      icon = Icons.image;
    } else if (evidence.type == 'audio') {
      icon = Icons.audiotrack;
    } else {
      icon = Icons.insert_drive_file;
    }

    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xFFC9A227),
        ),
        title: Text(
          evidence.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          evidence.type == 'image'
              ? 'عکس — برای مشاهده لمس کنید'
              : evidence.type == 'audio'
                  ? 'فایل صوتی — برای پخش لمس کنید'
                  : 'فایل — برای باز کردن لمس کنید',
        ),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => openEvidence(context, evidence),
      ),
    );
  }
}

class FullImagePage extends StatelessWidget {
  final String path;
  final String title;

  const FullImagePage({
    super.key,
    required this.path,
    this.title = 'تصویر مستند',
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: FutureBuilder<bool>(
          future: file.exists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            if (snapshot.data != true) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'تصویر پیدا نشد یا فایل حذف شده است.',
                  textAlign: TextAlign.center,
                ),
              );
            }

            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'تصویر قابل نمایش نیست.',
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// =====================================================
// اطلاعات
// =====================================================

class InfoCard
    extends StatelessWidget {
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
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  const TextStyle(
                color:
                    Color(0xFFC9A227),
                fontWeight:
                    FontWeight.bold,
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
// جستجوی بایگانی
// =====================================================

class SearchArchivePage
    extends StatefulWidget {
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
  final codeController =
      TextEditingController();

  List<Inspection> get results {
    final code =
        codeController.text.trim();

    if (code.isEmpty) {
      return [];
    }

    return widget.inspections
        .where(
          (item) =>
              item.agentCode
                  .contains(code),
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
        title:
            const Text('جستجوی بایگانی'),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(16),
            child: TextField(
              controller:
                  codeController,
              onChanged: (_) =>
                  setState(() {}),
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText: 'کد عامل',
                prefixIcon:
                    Icon(Icons.numbers),
                border:
                    OutlineInputBorder(),
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
                    itemCount:
                        data.length,
                    itemBuilder:
                        (context, index) {
                      final item =
                          data[index];

                      return Card(
                        child: ListTile(
                          title: Text(
                            item.agentCode,
                          ),
                          subtitle:
                              Text(
                            '${item.date} - ${item.city}',
                          ),
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
}
// =====================================================
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

  // استخراج ماه از تاریخ شمسی
  // مثال: ۱۴۰۵/۰۵/۲۰ -> ۱۴۰۵/۰۵
  String getMonth(String date) {
    final parts = date.split('/');

    if (parts.length >= 2) {
      return '${parts[0]}/${parts[1]}';
    }

    return date;
  }

  String persianMonthName(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return month;
    }
final m = int.tryParse(
      parts[1].replaceAllMapped(
        RegExp(r'[۰-۹]'),
        (match) {
          const p = '۰۱۲۳۴۵۶۷۸۹';
          return p.indexOf(match.group(0)!).toString();
        },
      ),
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

    if (m >= 1 && m <= 12) {
      return '${names[m]} ${parts[0]}';
    }

    return month;
  }

  List<String> get months {
    final result = widget.inspections
        .map((item) => getMonth(item.date))
        .where((month) => month.isNotEmpty)
        .toSet()
        .toList();

    result.sort((a, b) => b.compareTo(a));

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

    final groups =
        repeatedForMonth(selectedMonth!);

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
                final groups =
                    repeatedForMonth(month);

                final totalRepeated =
                    groups.length;

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
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '$totalRepeated عامل تکراری',
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
                              color:
                                  Color(0xFFC9A227),
                              fontSize: 28,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: groups.length,
                    itemBuilder:
                        (context, index) {
                      final code =
                          groups.keys.elementAt(index);

                      final records =
                          groups[code]!;

                      return Card(
                        child: ListTile(
                          leading:
                              const Icon(
                            Icons.store,
                            color:
                                Color(0xFFC9A227),
                          ),
                          title: Text(
                            code,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: Text(
                            '${records.length} بار در این ماه بازرسی شده',
                          ),
                          trailing:
                              const Icon(
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

  @override
  Widget build(BuildContext context) {
    final sortedRecords = [...records];

    sortedRecords.sort(
      (a, b) => a.date.compareTo(b.date),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'کد عامل: $code',
        ),
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
                  Text(
                    'بازرسی‌های تکراری',
                    style: const TextStyle(
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
                        fontWeight:
                            FontWeight.bold,
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
// صفحات فعلاً آماده توسعه
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
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage>
    with SingleTickerProviderStateMixin {
  List<Inspection> inspections = [];
  bool isLoading = true;

  int reportMode = 0; // 0 روزانه، 1 ماهانه، 2 بین دو تاریخ، 3 بر اساس شهر
  String selectedDate = '';
  String startDate = '';
  String endDate = '';
  String? selectedMonth;
  final Set<String> selectedCities = {};

  final TextEditingController agentSearchController =
      TextEditingController();
  String agentSearch = '';

  late final TabController tabController;

  static const Color gold = Color(0xFFC9A227);
  static const Color panel = Color(0xFF101B2E);

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
    selectedDate = gregorianToJalali(DateTime.now());
    startDate = selectedDate;
    endDate = selectedDate;
    _loadInspections();
  }

  @override
  void dispose() {
    tabController.dispose();
    agentSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInspections() async {
    final data = await AppStorage.getInspections();

    if (!mounted) return;

    final cities = data
        .map((e) => e.city.trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    setState(() {
      inspections = data;
      isLoading = false;
      selectedCities.removeWhere((city) => !cities.contains(city));
    });
  }

  bool _hasProblem(Inspection item) =>
      item.problems.trim().isNotEmpty;

  int _problemCount(List<Inspection> data) =>
      data.where(_hasProblem).length;

  double _problemPercent(List<Inspection> data) {
    if (data.isEmpty) return 0;
    return (_problemCount(data) / data.length) * 100;
  }

  String _monthOf(String date) {
    final parts = normalizeJalaliDate(date).split('/');
    if (parts.length != 3) return '';
    return '${parts[0]}/${parts[1]}';
  }

  List<String> _months() {
    final result = inspections
        .map((e) => _monthOf(e.date))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    result.sort(
      (a, b) => jalaliDateKey('${b.split('/')[0]}/${b.split('/')[1]}/01')
          .compareTo(
        jalaliDateKey('${a.split('/')[0]}/${a.split('/')[1]}/01'),
      ),
    );

    return result;
  }

  List<String> _cities() {
    final result = inspections
        .map((e) => e.city.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    result.sort();
    return result;
  }

  List<Inspection> _dateRangeRecords(
    String from,
    String to,
  ) {
    final fromKey = jalaliDateKey(from);
    final toKey = jalaliDateKey(to);

    if (fromKey == 0 || toKey == 0) return [];

    final low = fromKey <= toKey ? fromKey : toKey;
    final high = fromKey <= toKey ? toKey : fromKey;

    return inspections.where((item) {
      final key = jalaliDateKey(item.date);
      return key >= low && key <= high;
    }).toList();
  }

  List<Inspection> _recordsForReport() {
    switch (reportMode) {
      case 0:
        return inspections
            .where(
              (e) =>
                  normalizeJalaliDate(e.date) ==
                  normalizeJalaliDate(selectedDate),
            )
            .toList();

      case 1:
        final month = selectedMonth ?? (_months().isNotEmpty ? _months().first : '');
        if (month.isEmpty) return [];
        return inspections
            .where((e) => _monthOf(e.date) == month)
            .toList();

      case 2:
        return _dateRangeRecords(startDate, endDate);

      case 3:
        if (selectedCities.isEmpty) return inspections;
        return inspections
            .where((e) => selectedCities.contains(e.city.trim()))
            .toList();

      default:
        return inspections;
    }
  }

  int _distinctDays(List<Inspection> data) =>
      data.map((e) => normalizeJalaliDate(e.date)).toSet().length;

  Map<String, List<Inspection>> _cityGroups(List<Inspection> data) {
    final groups = <String, List<Inspection>>{};

    for (final item in data) {
      final city = item.city.trim();
      if (city.isEmpty) continue;
      groups.putIfAbsent(city, () => []).add(item);
    }

    return groups;
  }

  Map<String, List<Inspection>> _agentGroups(List<Inspection> data) {
    final groups = <String, List<Inspection>>{};

    for (final item in data) {
      final code = item.agentCode.trim();
      if (code.isEmpty) continue;
      groups.putIfAbsent(code, () => []).add(item);
    }

    return groups;
  }

  Future<void> _pickDate({
    required bool start,
  }) async {
    final result = await showJalaliDateDialog(
      context,
      initialDate: start ? startDate : endDate,
      title: start ? 'تاریخ شروع' : 'تاریخ پایان',
    );

    if (result == null || !mounted) return;

    setState(() {
      if (start) {
        startDate = result;
      } else {
        endDate = result;
      }
    });
  }

  Future<void> _pickDailyDate() async {
    final result = await showJalaliDateDialog(
      context,
      initialDate: selectedDate,
      title: 'تاریخ گزارش روزانه',
    );

    if (result == null || !mounted) return;

    setState(() {
      selectedDate = result;
    });
  }

  Future<void> _showCitySelector({
    bool forCharts = false,
  }) async {
    final cities = _cities();
    final temp = <String>{
      ...selectedCities,
    };

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('انتخاب شهرها'),
              content: SizedBox(
                width: double.maxFinite,
                height: 360,
                child: cities.isEmpty
                    ? const Center(
                        child: Text('هنوز شهری ثبت نشده است'),
                      )
                    : ListView.builder(
                        itemCount: cities.length,
                        itemBuilder: (_, index) {
                          final city = cities[index];
                          return CheckboxListTile(
                            value: temp.contains(city),
                            title: Text(city),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  temp.add(city);
                                } else {
                                  temp.remove(city);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    temp
                      ..clear()
                      ..addAll(cities);
                    setDialogState(() {});
                  },
                  child: const Text('انتخاب همه'),
                ),
                TextButton(
                  onPressed: () {
                    temp.clear();
                    setDialogState(() {});
                  },
                  child: const Text('پاک کردن'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedCities
                        ..clear()
                        ..addAll(temp);
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('تأیید'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _topTabs() {
    return Container(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        labelColor: gold,
        unselectedLabelColor: Colors.white70,
        indicatorColor: gold,
        tabs: const [
          Tab(text: 'آمار'),
          Tab(text: 'گزارش‌ها'),
          Tab(text: 'نمودارها'),
          Tab(text: 'سوابق عامل'),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final child = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: gold,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );

    if (onTap == null) return child;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: child,
    );
  }

  Widget _dateField({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gold.withOpacity(.65)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    color: gold,
                    size: 20,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      formatJalaliDate(value),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeSelector() {
    const modes = [
      'روزانه',
      'ماهانه',
      'بین دو تاریخ',
      'بر اساس شهر',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          modes.length,
          (index) => Padding(
            padding: const EdgeInsets.only(left: 7),
            child: ChoiceChip(
              selected: reportMode == index,
              label: Text(modes[index]),
              selectedColor: gold,
              labelStyle: TextStyle(
                color: reportMode == index
                    ? Colors.black
                    : Colors.white,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) {
                setState(() {
                  reportMode = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _reportsTab() {
    final data = _recordsForReport();
    final problems = _problemCount(data);
    final days = _distinctDays(data);
    final percent = _problemPercent(data);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _modeSelector(),
        const SizedBox(height: 12),
        if (reportMode == 0)
          _dateField(
            title: 'تاریخ گزارش',
            value: selectedDate,
            onTap: _pickDailyDate,
          ),
        if (reportMode == 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withOpacity(.65)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedMonth ??
                    (_months().isNotEmpty ? _months().first : null),
                isExpanded: true,
                hint: const Text('انتخاب ماه'),
                dropdownColor: panel,
                items: _months()
                    .map(
                      (month) => DropdownMenuItem(
                        value: month,
                        child: Text(jalaliMonthTitle(month)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedMonth = value;
                  });
                },
              ),
            ),
          ),
        ],
        if (reportMode == 2)
          Row(
            children: [
              _dateField(
                title: 'از تاریخ',
                value: startDate,
                onTap: () => _pickDate(start: true),
              ),
              const SizedBox(width: 8),
              _dateField(
                title: 'تا تاریخ',
                value: endDate,
                onTap: () => _pickDate(start: false),
              ),
            ],
          ),
        if (reportMode == 3)
          InkWell(
            onTap: () => _showCitySelector(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gold.withOpacity(.65)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_city, color: gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedCities.isEmpty
                          ? 'همه شهرها'
                          : '${selectedCities.length} شهر انتخاب شده',
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        _statCard(
          title: 'تعداد بازرسی',
          value: data.length.toString(),
          icon: Icons.assignment_turned_in,
        ),
        _statCard(
          title: 'تعداد مشکلات',
          value: problems.toString(),
          icon: Icons.warning_amber_rounded,
        ),
        _statCard(
          title: 'تعداد روزهای بازرسی',
          value: days.toString(),
          icon: Icons.calendar_month,
        ),
        _statCard(
          title: 'درصد مشکلات',
          value: '${percent.toStringAsFixed(1)}٪',
          icon: Icons.percent,
        ),
        if (reportMode == 3) _cityComparison(data),
        const SizedBox(height: 6),
        _managerReportCard(data),
      ],
    );
  }

  Widget _cityComparison(List<Inspection> data) {
    final groups = _cityGroups(data);
    if (groups.isEmpty) return const SizedBox.shrink();

    final cities = groups.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مقایسه شهرهای انتخاب‌شده',
            style: TextStyle(
              color: gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...cities.map(
            (city) {
              final cityData = groups[city]!;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_city,
                  color: gold,
                ),
                title: Text(city),
                subtitle: Text(
                  'بازرسی: ${cityData.length}  •  مشکلات: ${_problemCount(cityData)}  •  روز: ${_distinctDays(cityData)}',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _managerReportCard(List<Inspection> data) {
    final problems = _problemCount(data);
    final days = _distinctDays(data);
    final cities = _cityGroups(data);
    final percent = _problemPercent(data);

    final summary =
        'گزارش عملکرد بازرسی\n'
        'تاریخ/بازه: ${_reportTitle()}\n'
        'تعداد کل بازرسی: ${data.length}\n'
        'تعداد مشکلات: $problems\n'
        'تعداد روزهای بازرسی: $days\n'
        'درصد مشکلات: ${percent.toStringAsFixed(1)}٪\n'
        'تعداد شهرهای تحت پوشش: ${cities.length}\n';

    return Container(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(.65)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'گزارش قابل ارائه به مدیر',
            style: TextStyle(
              color: gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(summary),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportExcel(data),
                  icon: const Icon(Icons.table_chart),
                  label: const Text('خروجی Excel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportWord(data),
                  icon: const Icon(Icons.description),
                  label: const Text('خروجی Word'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reportTitle() {
    switch (reportMode) {
      case 0:
        return formatJalaliDate(selectedDate);
      case 1:
        final month = selectedMonth ??
            (_months().isNotEmpty ? _months().first : '');
        return jalaliMonthTitle(month);
      case 2:
        return '${formatJalaliDate(startDate)} تا ${formatJalaliDate(endDate)}';
      case 3:
        return selectedCities.isEmpty
            ? 'همه شهرها'
            : selectedCities.join('، ');
      default:
        return 'همه اطلاعات';
    }
  }

  Widget _statsTab() {
    final today = normalizeJalaliDate(
      gregorianToJalali(DateTime.now()),
    );
    final todayData = inspections
        .where((e) => normalizeJalaliDate(e.date) == today)
        .toList();

    final month = selectedMonth ??
        (_months().isNotEmpty ? _months().first : '');
    final monthData = month.isEmpty
        ? <Inspection>[]
        : inspections.where((e) => _monthOf(e.date) == month).toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          'آمار کلی',
          style: TextStyle(
            color: gold,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _statCard(
          title: 'کل بازرسی‌های ثبت‌شده',
          value: inspections.length.toString(),
          icon: Icons.assignment_turned_in,
        ),
        _statCard(
          title: 'کل مشکلات',
          value: _problemCount(inspections).toString(),
          icon: Icons.warning_amber_rounded,
        ),
        _statCard(
          title: 'امروز',
          value: todayData.length.toString(),
          icon: Icons.today,
        ),
        _statCard(
          title: 'این ماه',
          value: monthData.length.toString(),
          icon: Icons.calendar_month,
        ),
        _statCard(
          title: 'تعداد روزهای بازرسی',
          value: _distinctDays(inspections).toString(),
          icon: Icons.date_range,
        ),
        _statCard(
          title: 'تعداد شهرها',
          value: _cities().length.toString(),
          icon: Icons.location_city,
        ),
        const SizedBox(height: 10),
        if (month.isNotEmpty)
          _statCard(
            title: 'بازرسی‌های تکراری این ماه',
            value: _repeatedCount(month).toString(),
            icon: Icons.repeat,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RepeatedInspectionsPage(
                    inspections: inspections,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  int _repeatedCount(String month) {
    final groups = <String, int>{};

    for (final item in inspections) {
      if (_monthOf(item.date) != month) continue;
      final code = item.agentCode.trim();
      if (code.isEmpty) continue;
      groups[code] = (groups[code] ?? 0) + 1;
    }

    return groups.values
        .where((count) => count >= 2)
        .fold<int>(0, (sum, count) => sum + count);
  }

  Widget _chartsTab() {
    final data = _recordsForChart();
    final groups = _cityGroups(data);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gold.withOpacity(.65)),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _chartRangeValue,
                dropdownColor: panel,
                decoration: const InputDecoration(
                  labelText: 'بازه زمانی',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('همه اطلاعات'),
                  ),
                  DropdownMenuItem(
                    value: 'month',
                    child: Text('ماه انتخاب‌شده'),
                  ),
                  DropdownMenuItem(
                    value: 'range',
                    child: Text('بین دو تاریخ'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _chartRangeValue = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              if (_chartRangeValue == 'month')
                DropdownButtonFormField<String>(
                  value: selectedMonth ??
                      (_months().isNotEmpty ? _months().first : null),
                  dropdownColor: panel,
                  decoration: const InputDecoration(
                    labelText: 'ماه',
                    border: OutlineInputBorder(),
                  ),
                  items: _months()
                      .map(
                        (month) => DropdownMenuItem(
                          value: month,
                          child: Text(jalaliMonthTitle(month)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedMonth = value;
                    });
                  },
                ),
              if (_chartRangeValue == 'range')
                Row(
                  children: [
                    _dateField(
                      title: 'از تاریخ',
                      value: startDate,
                      onTap: () => _pickDate(start: true),
                    ),
                    const SizedBox(width: 8),
                    _dateField(
                      title: 'تا تاریخ',
                      value: endDate,
                      onTap: () => _pickDate(start: false),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _showCitySelector(forCharts: true),
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'انتخاب شهرها',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    selectedCities.isEmpty
                        ? 'همه شهرها'
                        : selectedCities.join('، '),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (groups.isEmpty)
          const Card(
            color: panel,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('داده‌ای برای نمودار وجود ندارد'),
              ),
            ),
          )
        else ...[
          _chartCard(
            title: 'درصد بازرسی هر شهر',
            data: groups.map(
              (city, value) => MapEntry(city, value.length.toDouble()),
            ),
            percentage: true,
          ),
          _chartCard(
            title: 'تعداد بازرسی هر شهر',
            data: groups.map(
              (city, value) => MapEntry(city, value.length.toDouble()),
            ),
          ),
          _chartCard(
            title: 'تعداد مشکلات هر شهر',
            data: groups.map(
              (city, value) => MapEntry(
                city,
                _problemCount(value).toDouble(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _chartRangeValue = 'all';

  List<Inspection> _recordsForChart() {
    List<Inspection> result;

    switch (_chartRangeValue) {
      case 'month':
        final month = selectedMonth ??
            (_months().isNotEmpty ? _months().first : '');
        result = month.isEmpty
            ? []
            : inspections.where((e) => _monthOf(e.date) == month).toList();
        break;
      case 'range':
        result = _dateRangeRecords(startDate, endDate);
        break;
      default:
        result = [...inspections];
    }

    if (selectedCities.isNotEmpty) {
      result = result
          .where((e) => selectedCities.contains(e.city.trim()))
          .toList();
    }

    return result;
  }

  Widget _chartCard({
    required String title,
    required Map<String, double> data,
    bool percentage = false,
  }) {
    final total = data.values.fold<double>(0, (a, b) => a + b);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ...sorted.map((entry) {
            final percent = total == 0 ? 0 : entry.value / total;
            final label = percentage
                ? '${(percent * 100).toStringAsFixed(1)}٪'
                : entry.value.toStringAsFixed(0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 13,
                      backgroundColor: Colors.white10,
                      color: gold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _agentHistoryTab() {
    final query = agentSearch.trim();

    final data = inspections.where((item) {
      if (query.isEmpty) return false;
      return item.agentCode.contains(query) ||
          item.agentName.contains(query);
    }).toList();

    final groups = _agentGroups(data);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: agentSearchController,
          onChanged: (value) {
            setState(() {
              agentSearch = value;
            });
          },
          decoration: const InputDecoration(
            labelText: 'جستجوی کد یا نام عامل',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (query.isEmpty)
          const Card(
            color: panel,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'کد یا نام عامل را وارد کنید تا تمام سوابق، تاریخ‌ها و تعداد بازرسی‌ها نمایش داده شود.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (groups.isEmpty)
          const Card(
            color: panel,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'برای این عامل سابقه‌ای پیدا نشد.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...groups.entries.map(
            (entry) {
              final records = [...entry.value]
                ..sort(
                  (a, b) => jalaliDateKey(b.date)
                      .compareTo(jalaliDateKey(a.date)),
                );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gold.withOpacity(.65)),
                ),
                child: ExpansionTile(
                  title: Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: gold,
                    ),
                  ),
                  subtitle: Text(
                    '${records.length} بار بازرسی',
                  ),
                  children: records.map(
                    (item) {
                      return ListTile(
                        leading: const Icon(
                          Icons.calendar_month,
                          color: gold,
                        ),
                        title: Text(
                          formatJalaliDate(item.date),
                        ),
                        subtitle: Text(
                          '${item.agentName.isEmpty ? 'بدون نام' : item.agentName}  •  ${item.city.isEmpty ? 'بدون شهر' : item.city}',
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
                      );
                    },
                  ).toList(),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _exportExcel(List<Inspection> data) async {
    try {
      final workbook = Excel.createExcel();
      final sheet = workbook['گزارش'];
      final cities = _cityGroups(data);

      final rows = <List<String>>[
        ['گزارش عملکرد بازرسی'],
        ['بازه', _reportTitle()],
        ['تعداد بازرسی', data.length.toString()],
        ['تعداد مشکلات', _problemCount(data).toString()],
        ['تعداد روزهای بازرسی', _distinctDays(data).toString()],
        ['درصد مشکلات', '${_problemPercent(data).toStringAsFixed(1)}٪'],
        [],
        ['شهر', 'تعداد بازرسی', 'تعداد مشکلات', 'تعداد روزهای بازرسی'],
      ];

      for (final entry in cities.entries) {
        rows.add([
          entry.key,
          entry.value.length.toString(),
          _problemCount(entry.value).toString(),
          _distinctDays(entry.value).toString(),
        ]);
      }

      rows.add([]);
      rows.add(['تاریخ', 'کد عامل', 'نام عامل', 'شهر', 'مشکل']);

      for (final item in data) {
        rows.add([
          formatJalaliDate(item.date),
          item.agentCode,
          item.agentName,
          item.city,
          _hasProblem(item) ? 'دارد' : 'ندارد',
        ]);
      }

      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          sheet.updateCell(
            CellIndex.indexByColumnRow(
              columnIndex: c,
              rowIndex: r,
            ),
            TextCellValue(rows[r][c]),
          );
        }
      }

      for (var c = 0; c < 5; c++) {
        sheet.setColumnWidth(c, c == 0 ? 18 : 22);
      }

      final bytes = workbook.save();
      if (bytes == null) {
        throw Exception('خطا در ساخت Excel');
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/گزارش_بازرسی_${DateTime.now().millisecondsSinceEpoch}.xlsx',
      );
      await file.writeAsBytes(bytes, flush: true);

      await OpenFilex.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فایل Excel ساخته شد'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ساخت Excel: $e'),
        ),
      );
    }
  }

  Future<void> _exportWord(List<Inspection> data) async {
    try {
      final document = docx.loadDocxDocument();

      document.addHeading(
        text: 'گزارش عملکرد بازرسی',
        level: 1,
      );

      document.addParagraph(
        text: 'بازه گزارش: ${_reportTitle()}',
      );
      document.addParagraph(
        text: 'تعداد کل بازرسی: ${data.length}',
      );
      document.addParagraph(
        text: 'تعداد مشکلات: ${_problemCount(data)}',
      );
      document.addParagraph(
        text: 'تعداد روزهای بازرسی: ${_distinctDays(data)}',
      );
      document.addParagraph(
        text:
            'درصد مشکلات: ${_problemPercent(data).toStringAsFixed(1)}٪',
      );

      final cities = _cityGroups(data);

      if (cities.isNotEmpty) {
        document.addHeading(
          text: 'آمار شهرها',
          level: 2,
        );

        final table = document.addTable(
          cities.length + 1,
          4,
          style: 'Table Grid',
        );

        table.cell(0, 0).text = 'شهر';
        table.cell(0, 1).text = 'بازرسی';
        table.cell(0, 2).text = 'مشکلات';
        table.cell(0, 3).text = 'روز';

        var row = 1;
        for (final entry in cities.entries) {
          table.cell(row, 0).text = entry.key;
          table.cell(row, 1).text = entry.value.length.toString();
          table.cell(row, 2).text =
              _problemCount(entry.value).toString();
          table.cell(row, 3).text =
              _distinctDays(entry.value).toString();
          row++;
        }
      }

      document.addHeading(
        text: 'جزئیات بازرسی‌ها',
        level: 2,
      );

      final table = document.addTable(
        data.length + 1,
        5,
        style: 'Table Grid',
      );

      table.cell(0, 0).text = 'تاریخ';
      table.cell(0, 1).text = 'کد عامل';
      table.cell(0, 2).text = 'نام عامل';
      table.cell(0, 3).text = 'شهر';
      table.cell(0, 4).text = 'مشکل';

      for (var i = 0; i < data.length; i++) {
        final item = data[i];
        final row = i + 1;
        table.cell(row, 0).text =
            formatJalaliDate(item.date);
        table.cell(row, 1).text = item.agentCode;
        table.cell(row, 2).text = item.agentName;
        table.cell(row, 3).text = item.city;
        table.cell(row, 4).text =
            _hasProblem(item) ? 'دارد' : 'ندارد';
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/گزارش_بازرسی_${DateTime.now().millisecondsSinceEpoch}.docx',
      );

      document.save(file.path);

      await OpenFilex.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فایل Word ساخته شد'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ساخت Word: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('آمار و گزارش‌ها'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('آمار و گزارش‌ها'),
          bottom: TabBar(
            controller: tabController,
            isScrollable: true,
            labelColor: gold,
            unselectedLabelColor: Colors.white70,
            indicatorColor: gold,
            tabs: const [
              Tab(text: 'آمار'),
              Tab(text: 'گزارش‌ها'),
              Tab(text: 'نمودارها'),
              Tab(text: 'سوابق عامل'),
            ],
          ),
        ),
        body: TabBarView(
          controller: tabController,
          children: [
            _statsTab(),
            _reportsTab(),
            _chartsTab(),
            _agentHistoryTab(),
          ],
        ),
      ),
    );
  }
}

class SettingsPage
    extends StatelessWidget {
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

class SimplePage
    extends StatelessWidget {
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
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 80,
                color:
                    const Color(0xFFC9A227),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Color(0xFFC9A227),
                  fontSize: 24,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.white70,
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
