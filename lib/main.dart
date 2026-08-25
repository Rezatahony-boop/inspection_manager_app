import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

class InspectionDetailsPage
    extends StatelessWidget {
  final Inspection inspection;

  const InspectionDetailsPage({
    super.key,
    required this.inspection,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('جزئیات بازرسی'),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          InfoCard(
            title: 'کد عامل',
            value:
                inspection.agentCode,
          ),
          InfoCard(
            title: 'نام عامل',
            value: inspection
                    .agentName.isEmpty
                ? 'ثبت نشده'
                : inspection.agentName,
          ),
          InfoCard(
            title: 'شهر',
            value:
                inspection.city.isEmpty
                    ? 'ثبت نشده'
                    : inspection.city,
          ),
          InfoCard(
            title: 'تاریخ',
            value:
                inspection.date,
          ),
          InfoCard(
            title: 'شرح مشکلات',
            value:
                inspection.problems.isEmpty
                    ? 'ثبت نشده'
                    : inspection.problems,
          ),

          const SizedBox(height: 10),

          EvidenceViewer(
            evidences:
                inspection.evidences,
          ),
        ],
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
// گزارش‌ها و آمار پیشرفته
// =====================================================

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

enum ReportPeriodMode { currentMonth, dateRange }

class _ReportsPageState extends State<ReportsPage> {
  List<Inspection> inspections = [];
  bool isLoading = true;
  ReportPeriodMode periodMode = ReportPeriodMode.currentMonth;
  String selectedMonth = '';
  String startDate = '';
  String endDate = '';
  final Set<String> selectedCities = <String>{};
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    final today = gregorianToJalali(DateTime.now());
    selectedMonth = _getMonth(today);
    startDate = today;
    endDate = today;
    _loadInspections();
  }

  Future<void> _loadInspections() async {
    try {
      final data = await AppStorage.getInspections();
      if (!mounted) return;
      setState(() {
        inspections = data;
        isLoading = false;
        _ensureCities();
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
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(persian[i], english[i]);
      result = result.replaceAll(arabic[i], english[i]);
    }
    return result;
  }

  String _toPersian(String value) => toPersianDigits(value);

  String _getMonth(String date) {
    final parts = date.trim().split('/');
    if (parts.length < 2) return '';
    return '${_normalizeDigits(parts[0])}/${_normalizeDigits(parts[1]).padLeft(2, '0')}';
  }

  int _dateKey(String date) {
    final parts = _normalizeDigits(date).split('/');
    if (parts.length < 3) return 0;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final d = int.tryParse(parts[2]) ?? 0;
    return y * 10000 + m * 100 + d;
  }

  int _monthKey(String month) {
    final parts = _normalizeDigits(month).split('/');
    if (parts.length < 2) return 0;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return y * 100 + m;
  }

  String _monthName(String month) {
    final parts = _normalizeDigits(month).split('/');
    if (parts.length != 2) return month;
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
    final m = int.tryParse(parts[1]) ?? 0;
    if (m < 1 || m > 12) return month;
    return '${names[m]} ${_toPersian(parts[0])}';
  }

  List<String> get _months {
    final result = inspections
        .map((e) => _getMonth(e.date))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    result.sort((a, b) => _monthKey(b).compareTo(_monthKey(a)));
    if (selectedMonth.isNotEmpty && !result.contains(selectedMonth)) {
      result.insert(0, selectedMonth);
    }
    return result;
  }

  List<String> get _cities {
    final result = inspections
        .map((e) => e.city.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    result.sort();
    return result;
  }

  void _ensureCities() {
    final cities = _cities.toSet();
    selectedCities.removeWhere((c) => !cities.contains(c));
    if (selectedCities.isEmpty && cities.isNotEmpty) {
      selectedCities.addAll(cities);
    }
  }

  List<Inspection> get _periodRecords {
    if (periodMode == ReportPeriodMode.currentMonth) {
      return inspections.where((e) => _getMonth(e.date) == selectedMonth).toList();
    }
    final start = _dateKey(startDate);
    final end = _dateKey(endDate);
    final from = start <= end ? start : end;
    final to = start <= end ? end : start;
    return inspections.where((e) {
      final key = _dateKey(e.date);
      return key >= from && key <= to;
    }).toList();
  }

  bool _hasProblem(Inspection item) => item.problems.trim().isNotEmpty;

  int _problemCount(List<Inspection> records) => records.where(_hasProblem).length;

  double _problemPercent(List<Inspection> records) {
    if (records.isEmpty) return 0;
    return (_problemCount(records) / records.length) * 100;
  }

  Map<String, List<Inspection>> _cityGroups(List<Inspection> records) {
    final Map<String, List<Inspection>> result = {};
    for (final item in records) {
      final city = item.city.trim();
      if (city.isEmpty) continue;
      result.putIfAbsent(city, () => []).add(item);
    }
    return result;
  }

  List<Inspection> _cityRecords(String? city) {
    if (city == null || city.isEmpty) return [];
    return _periodRecords.where((e) => e.city.trim() == city).toList();
  }

  Future<String?> _pickJalaliDate({String? initial}) async {
    final parts = _normalizeDigits(initial ?? gregorianToJalali(DateTime.now())).split('/');
    int year = int.tryParse(parts.length > 0 ? parts[0] : '') ?? 1405;
    int month = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    int day = int.tryParse(parts.length > 2 ? parts[2] : '') ?? 1;
    month = month.clamp(1, 12).toInt();
    day = day.clamp(1, _jalaliMonthDays(year, month)).toInt();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxDay = _jalaliMonthDays(year, month);
            if (day > maxDay) day = maxDay;
            final years = List<int>.generate(31, (i) => year - 15 + i);
            return AlertDialog(
              title: const Text('انتخاب تاریخ شمسی'),
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: day,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'روز'),
                        items: List.generate(maxDay, (i) => i + 1)
                            .map((v) => DropdownMenuItem(value: v, child: Text(_toPersian('$v'))))
                            .toList(),
                        onChanged: (v) => setDialogState(() => day = v ?? day),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: month,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'ماه'),
                        items: List.generate(12, (i) => i + 1)
                            .map((v) => DropdownMenuItem(value: v, child: Text(_monthName('1405/${v.toString().padLeft(2, '0')}').split(' ').first)))
                            .toList(),
                        onChanged: (v) => setDialogState(() {
                          month = v ?? month;
                          day = day.clamp(1, _jalaliMonthDays(year, month)).toInt();
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: year,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'سال'),
                        items: years
                            .map((v) => DropdownMenuItem(value: v, child: Text(_toPersian('$v'))))
                            .toList(),
                        onChanged: (v) => setDialogState(() {
                          year = v ?? year;
                          day = day.clamp(1, _jalaliMonthDays(year, month)).toInt();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('انصراف')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    '${_toPersian(year.toString().padLeft(4, '0'))}/${_toPersian(month.toString().padLeft(2, '0'))}/${_toPersian(day.toString().padLeft(2, '0'))}',
                  ),
                  child: const Text('تأیید'),
                ),
              ],
            );
          },
        );
      },
    );
    return result;
  }

  int _jalaliMonthDays(int year, int month) {
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    return _isJalaliLeap(year) ? 30 : 29;
  }

  bool _isJalaliLeap(int year) {
    final mod = year % 33;
    const leapRemainders = [1, 5, 9, 13, 17, 22, 26, 30];
    return leapRemainders.contains(mod);
  }

  Future<void> _selectRangeStart() async {
    final value = await _pickJalaliDate(initial: startDate);
    if (value == null) return;
    setState(() => startDate = value);
  }

  Future<void> _selectRangeEnd() async {
    final value = await _pickJalaliDate(initial: endDate);
    if (value == null) return;
    setState(() => endDate = value);
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      color: const Color(0xFF101B2E),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFC9A227),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            Text(value, style: const TextStyle(color: Color(0xFFC9A227), fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _periodSelector() {
    return Card(
      color: const Color(0xFF101B2E),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const SizedBox(width: double.infinity, child: Center(child: Text('ماه جاری'))),
                selected: periodMode == ReportPeriodMode.currentMonth,
                onSelected: (_) => setState(() => periodMode = ReportPeriodMode.currentMonth),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const SizedBox(width: double.infinity, child: Center(child: Text('بین دو تاریخ'))),
                selected: periodMode == ReportPeriodMode.dateRange,
                onSelected: (_) => setState(() => periodMode = ReportPeriodMode.dateRange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodDetails() {
    if (periodMode == ReportPeriodMode.currentMonth) {
      final months = _months;
      if (months.isEmpty) return const SizedBox.shrink();
      if (!months.contains(selectedMonth)) selectedMonth = months.first;
      return Card(
        color: const Color(0xFF101B2E),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedMonth,
              isExpanded: true,
              dropdownColor: const Color(0xFF101B2E),
              icon: const Icon(Icons.calendar_month),
              items: months.map((m) => DropdownMenuItem(value: m, child: Text(_monthName(m)))).toList(),
              onChanged: (v) => setState(() => selectedMonth = v ?? selectedMonth),
            ),
          ),
        ),
      );
    }

    return Card(
      color: const Color(0xFF101B2E),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _dateButton('از تاریخ', startDate, _selectRangeStart)),
                const SizedBox(width: 8),
                Expanded(child: _dateButton('تا تاریخ', endDate, _selectRangeEnd)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('بازه انتخابی شامل هر دو تاریخ ابتدا و انتها است.'),
          ],
        ),
      ),
    );
  }

  Widget _dateButton(String title, String date, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.event),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(title, style: const TextStyle(fontSize: 12)), Text(date)],
      ),
    );
  }

  Widget _citySelectors() {
    final cities = _cities;
    if (cities.isEmpty) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFF101B2E),
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('انتخاب شهرها برای مقایسه', style: TextStyle(color: Color(0xFFC9A227), fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${_toPersian('${selectedCities.length}')} شهر انتخاب شده'),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('انتخاب همه شهرها'),
            value: selectedCities.length == cities.length,
            tristate: selectedCities.isNotEmpty && selectedCities.length < cities.length,
            onChanged: (v) => setState(() { if (v == true) selectedCities.addAll(cities); else selectedCities.clear(); }),
          ),
          const Divider(),
          ...cities.map((city) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(city),
            value: selectedCities.contains(city),
            onChanged: (v) => setState(() { if (v == true) selectedCities.add(city); else selectedCities.remove(city); }),
          )),
        ]),
      ),
    );
  }

  Widget _cityComparison() {
    final groups = <String, List<Inspection>>{};
    for (final city in selectedCities) {
      final data = _cityRecords(city);
      if (data.isNotEmpty) groups[city] = data;
    }
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      const Text('مقایسه شهرهای انتخاب‌شده', style: TextStyle(color: Color(0xFFC9A227), fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      _multiChart('تعداد بازرسی', groups, (r) => r.length.toDouble(), 1),
      _multiChart('تعداد مشکلات', groups, (r) => _problemCount(r).toDouble(), 1),
      _multiChart('درصد بازرسی‌های دارای مشکل', groups, _problemPercent, 100),
    ]);
  }

  Widget _multiChart(String title, Map<String, List<Inspection>> groups, double Function(List<Inspection>) valueOf, double fixedMax) {
    final maxValue = fixedMax == 1 ? groups.values.map(valueOf).fold<double>(1, (a,b) => a>b?a:b) : fixedMax;
    return Card(
      color: const Color(0xFF101B2E),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...groups.entries.map((e) {
          final value = valueOf(e.value).clamp(0, maxValue).toDouble();
          final ratio = maxValue <= 0 ? 0.0 : (value/maxValue).clamp(0,1).toDouble();
          final shown = fixedMax == 100 ? '${_toPersian(value.toStringAsFixed(1))}٪' : _toPersian(value.round().toString());
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(e.key)), Text(shown, style: const TextStyle(color: Color(0xFFC9A227), fontWeight: FontWeight.bold))]),
            const SizedBox(height: 5),
            LinearProgressIndicator(value: ratio),
          ]));
        }),
      ])),
    );
  }

  Map<String, List<Inspection>> _repeatedGroupsForPeriod() {
    final groups = <String, List<Inspection>>{};
    for (final item in _periodRecords) {
      final code = item.agentCode.trim();
      if (code.isNotEmpty) groups.putIfAbsent(code, () => []).add(item);
    }
    groups.removeWhere((k,v) => v.length < 2);
    return groups;
  }

  Widget _repeatedCard() {
    final groups = _repeatedGroupsForPeriod();
    return Card(
      color: const Color(0xFF101B2E),
      margin: const EdgeInsets.only(top: 20),
      child: ListTile(
        leading: const Icon(Icons.repeat, color: Color(0xFFC9A227), size: 32),
        title: const Text('بازرسی‌های تکراری'),
        subtitle: Text(groups.isEmpty ? 'مورد تکراری در این بازه پیدا نشد.' : '${_toPersian('${groups.length}')} کد عامل تکراری است.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RepeatedInspectionsPage(inspections: inspections))),
      ),
    );
  }

  Future<void> _exportExcel() async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      final excel = Excel.createExcel();
      final records = _periodRecords;
      final summary = excel['خلاصه گزارش'];
      summary.appendRow([TextCellValue('سامانه مدیریت بازرسی'), TextCellValue('')]);
      summary.appendRow([TextCellValue('بازه گزارش'), TextCellValue(_reportTitleForFile())]);
      summary.appendRow([TextCellValue('کل بازرسی‌ها'), IntCellValue(records.length)]);
      summary.appendRow([TextCellValue('دارای مشکل'), IntCellValue(_problemCount(records))]);
      summary.appendRow([TextCellValue('بدون مشکل'), IntCellValue(records.length-_problemCount(records))]);
      summary.appendRow([TextCellValue('درصد دارای مشکل'), DoubleCellValue(_problemPercent(records))]);
      final citySheet = excel['مقایسه شهرها'];
      citySheet.appendRow([TextCellValue('شهر'),TextCellValue('بازرسی'),TextCellValue('مشکل'),TextCellValue('درصد مشکل')]);
      final groups = _cityGroups(records);
      final cities = selectedCities.isEmpty ? (groups.keys.toList()..sort()) : (selectedCities.toList()..sort());
      for (final city in cities) {
        final data=groups[city] ?? <Inspection>[];
        citySheet.appendRow([TextCellValue(city),IntCellValue(data.length),IntCellValue(_problemCount(data)),DoubleCellValue(_problemPercent(data))]);
      }
      final details = excel['جزئیات بازرسی‌ها'];
      details.appendRow([TextCellValue('تاریخ'),TextCellValue('کد عامل'),TextCellValue('نام عامل'),TextCellValue('شهر'),TextCellValue('شرح مشکلات')]);
      for (final item in records) {
        details.appendRow([TextCellValue(item.date),TextCellValue(item.agentCode),TextCellValue(item.agentName),TextCellValue(item.city),TextCellValue(item.problems.isEmpty?'بدون مشکل':item.problems)]);
      }
      final repeated = excel['بازرسی‌های تکراری'];
      repeated.appendRow([TextCellValue('کد عامل'),TextCellValue('تعداد تکرار')]);
      for (final e in _repeatedGroupsForPeriod().entries) { repeated.appendRow([TextCellValue(e.key),IntCellValue(e.value.length)]); }
      final bytes = excel.save();
      if (bytes == null || bytes.isEmpty) throw Exception('Excel file is empty');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/گزارش_مدیریتی_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes, flush:true);
      final result = await OpenFilex.open(file.path);
      if (mounted) _showExportMessage(result.type == ResultType.done ? 'فایل Excel با موفقیت ساخته شد.' : 'فایل Excel ساخته شد؛ برنامه Excel برای باز کردن آن پیدا نشد.');
    } catch (e) {
      if (mounted) _showExportMessage('خطا در ساخت Excel: $e');
    } finally { if (mounted) setState(() => exporting=false); }
  }

  Future<void> _exportPdf() async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      final doc = pw.Document();
      final records = _periodRecords;
      final groups = _cityGroups(records);
      final cities = selectedCities.isEmpty ? (groups.keys.toList()..sort()) : (selectedCities.toList()..sort());
      doc.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, build: (_) => [
        pw.Text('Inspection Management Report', style: pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),
        pw.SizedBox(height:10),
        pw.Text('Report period: ${_reportTitleForFile()}'),
        pw.Text('Total inspections: ${records.length}'),
        pw.Text('Inspections with problems: ${_problemCount(records)}'),
        pw.Text('Problem percentage: ${_problemPercent(records).toStringAsFixed(1)}%'),
        pw.SizedBox(height:15),
        pw.Text('Selected cities'),
        if (cities.isNotEmpty) pw.Table.fromTextArray(headers:['City','Inspections','Problems','Problem %'], data:cities.map((city){final d=groups[city]??<Inspection>[];return [city,'${d.length}','${_problemCount(d)}','${_problemPercent(d).toStringAsFixed(1)}%'];}).toList()),
        pw.SizedBox(height:15),
        pw.Text('Inspection details'),
        if (records.isNotEmpty) pw.Table.fromTextArray(headers:['Date','Agent code','Agent name','City','Problem'],data:records.map((x)=>[x.date,x.agentCode,x.agentName,x.city,x.problems.isEmpty?'No':x.problems]).toList(),cellStyle:const pw.TextStyle(fontSize:7)),
      ]));
      final bytes=await doc.save();
      if(bytes.isEmpty) throw Exception('PDF file is empty');
      final dir=await getApplicationDocumentsDirectory();
      final file=File('${dir.path}/گزارش_مدیریتی_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes,flush:true);
      final result=await OpenFilex.open(file.path);
      if(mounted) _showExportMessage(result.type==ResultType.done?'PDF با موفقیت ساخته شد.':'PDF ساخته شد؛ برنامه PDF برای باز کردن آن پیدا نشد.');
    } catch(e) { if(mounted) _showExportMessage('خطا در ساخت PDF: $e'); }
    finally { if(mounted) setState(()=>exporting=false); }
  }

  Widget _exportButtons() {
    return Card(
      color: const Color(0xFF101B2E),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('خروجی برای ارائه به مدیر', style: TextStyle(color: Color(0xFFC9A227), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: exporting ? null : _exportPdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: exporting ? null : _exportExcel, icon: const Icon(Icons.table_chart), label: const Text('Excel'))),
              ],
            ),
            if (exporting) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _citySummary() {
    final groups = _cityGroups(_periodRecords);
    if (groups.isEmpty) return const SizedBox.shrink();
    final cities = groups.keys.toList()..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('آمار شهرها', style: TextStyle(color: Color(0xFFC9A227), fontSize: 21, fontWeight: FontWeight.bold)),
        ...cities.map((city) {
          final data = groups[city]!;
          return Card(
            color: const Color(0xFF101B2E),
            child: ListTile(
              leading: const Icon(Icons.location_city, color: Color(0xFFC9A227)),
              title: Text(city),
              subtitle: Text('بازرسی: ${_toPersian('${data.length}')}  •  مشکل: ${_toPersian('${_problemCount(data)}')}  •  درصد: ${_toPersian(_problemPercent(data).toStringAsFixed(1))}٪'),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('آمار و گزارش‌ها')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInspections,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (inspections.isEmpty)
                    const Card(
                      color: Color(0xFF101B2E),
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('هنوز هیچ بازرسی‌ای ثبت نشده است.', textAlign: TextAlign.center),
                      ),
                    )
                  else ...[
                    _periodSelector(),
                    _periodDetails(),
                    _summary(),
                    _citySelectors(),
                    _cityComparison(),
                    _citySummary(),
                    _repeatedCard(),
                    const SizedBox(height: 8),
                    _exportButtons(),
                  ],
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
