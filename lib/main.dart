import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
          FilePicker.platform.pickFiles()

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

      setState(() {
        recording = false;
      });

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
      setState(() {
        recording = false;
      });

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
  State<ArchivePage> createState() =>
      _ArchivePageState();
}

class _ArchivePageState
    extends State<ArchivePage> {
  List<Inspection> inspections = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data =
        await AppStorage.getInspections();

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
        actions: [
          IconButton(
            tooltip: 'بازرسی‌های تکراری',
            icon: const Icon(
              Icons.repeat,
            ),
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
          ),
          IconButton(
            tooltip: 'جستجو',
            icon: const Icon(
              Icons.search,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SearchArchivePage(
                    inspections: inspections,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : dates.isEmpty
              ? const Center(
                  child: Text(
                    'هنوز هیچ بازرسی ثبت نشده است',
                    style:
                        TextStyle(fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(12),
                  itemCount: dates.length,
                  itemBuilder:
                      (context, index) {
                    final date =
                        dates[index];

                    final count =
                        inspections
                            .where(
                              (item) =>
                                  item.date ==
                                  date,
                            )
                            .length;

                    return Card(
                      child: ListTile(
                        leading:
                            const Icon(
                          Icons
                              .calendar_month,
                          color: Color(
                            0xFFC9A227,
                          ),
                        ),
                        title: Text(
                          date,
                          style:
                              const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        subtitle:
                            Text(
                          '$count بازرسی',
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
                                  DailyArchivePage(
                                date: date,
                                inspections:
                                    inspections,
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

class EvidenceTile
    extends StatelessWidget {
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
      icon =
          Icons.insert_drive_file;
    }

    return Card(
      child: ListTile(
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
        subtitle: Text(
          evidence.type == 'image'
              ? 'عکس'
              : evidence.type == 'audio'
                  ? 'فایل صوتی'
                  : 'فایل',
        ),
        trailing:
            evidence.type == 'image'
                ? const Icon(
                    Icons.open_in_new,
                  )
                : null,
        onTap: evidence.type ==
                'image'
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FullImagePage(
                      path:
                          evidence.path,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }
}

class FullImagePage
    extends StatelessWidget {
  final String path;

  const FullImagePage({
    super.key,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تصویر مستند'),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(path),
            errorBuilder:
                (_, __, ___) =>
                    const Text(
              'تصویر قابل نمایش نیست',
            ),
          ),
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
          parts[1].replaceAll(
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

class ReportsPage
    extends StatelessWidget {
  const ReportsPage({
    super.key,
  });

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
