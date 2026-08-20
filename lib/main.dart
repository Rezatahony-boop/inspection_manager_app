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
  final jDayNo =
      gDayNo - _gregorianDayNumber(1600, 3, 21);

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

int _gregorianDayNumber(
  int gy,
  int gm,
  int gd,
) {
  final gy2 = gy + ((gm > 2) ? 1 : 0);

  return (365 * gy) +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) +
      gd +
      _gregorianMonthDays(gm, gy);
}

int _gregorianMonthDays(
  int gm,
  int gy,
) {
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

  factory EvidenceFile.fromJson(
    Map<String, dynamic> json,
  ) {
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

  factory Inspection.fromJson(
    Map<String, dynamic> json,
  ) {
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
      agentCode:
          json['agentCode']?.toString() ?? '',
      agentName:
          json['agentName']?.toString() ?? '',
      city:
          json['city']?.toString() ?? '',
      problems:
          json['problems']?.toString() ?? '',
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
  static const String inspectionsKey =
      'inspections';

  static Future<List<Inspection>>
      getInspections() async {
    final prefs =
        await SharedPreferences.getInstance();

    final data =
        prefs.getString(inspectionsKey);

    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded =
          jsonDecode(data);

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
    final prefs =
        await SharedPreferences.getInstance();

    final data = inspections
        .map(
          (inspection) => inspection.toJson(),
        )
        .toList();

    await prefs.setString(
      inspectionsKey,
      jsonEncode(data),
    );
  }

  static Future<void> addInspection(
    Inspection inspection,
  ) async {
    final inspections =
        await getInspections();

    inspections.insert(0, inspection);

    await saveInspections(inspections);
  }

  static Future<void> updateInspection(
    Inspection updated,
  ) async {
    final inspections =
        await getInspections();

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

Future<Directory>
    getEvidenceDirectory() async {
  final base =
      await getApplicationDocumentsDirectory();

  final directory = Directory(
    '${base.path}/inspection_evidence',
  );

  if (!await directory.exists()) {
    await directory.create(
      recursive: true,
    );
  }

  return directory;
}

// =====================================================
// ورود
// =====================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState
    extends State<LoginPage> {
  final passwordController =
      TextEditingController();

  void login() {
    if (passwordController.text == '1234') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const DashboardPage(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('رمز عبور اشتباه است'),
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
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user,
                size: 82,
                color:
                    Color(0xFFC9A227),
              ),
              const SizedBox(height: 20),
              const Text(
                'سامانه مدیریت بازرسی',
                style: TextStyle(
                  color:
                      Color(0xFFC9A227),
                  fontSize: 25,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller:
                    passwordController,
                obscureText: true,
                onSubmitted: (_) =>
                    login(),
                decoration:
                    const InputDecoration(
                  labelText: 'رمز ورود',
                  prefixIcon:
                      Icon(Icons.lock),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width:
                    double.infinity,
                height: 52,
                child:
                    ElevatedButton(
                  onPressed: login,
                  child:
                      const Text(
                    'ورود به برنامه',
                    style:
                        TextStyle(
                      fontSize: 17,
                    ),
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

class DashboardPage
    extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('داشبورد'),
      ),
      body: GridView.count(
        padding:
            const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: [
          DashboardButton(
            title:
                'ثبت بازرسی جدید',
            icon:
                Icons.assignment_add,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const NewInspectionPage(),
                ),
              );
            },
          ),
          DashboardButton(
            title:
                'ثبت عملکرد روزانه',
            icon: Icons.today,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const DailyPerformancePage(),
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
                  builder: (_) =>
                      const ArchivePage(),
                ),
              );
            },
          ),
          DashboardButton(
            title: 'گزارش‌ها',
            icon:
                Icons.bar_chart,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ReportsPage(),
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
                  builder: (_) =>
                      const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class DashboardButton
    extends StatelessWidget {
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
      color:
          const Color(0xFF101B2E),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 46,
              color:
                  const Color(0xFFC9A227),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight:
                    FontWeight.w600,
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

class NewInspectionPage
    extends StatefulWidget {
  const NewInspectionPage({
    super.key,
  });

  @override
  State<NewInspectionPage> createState() =>
      _NewInspectionPageState();
}

class _NewInspectionPageState
    extends State<NewInspectionPage> {
  final dateController =
      TextEditingController();
  final agentCodeController =
      TextEditingController();
  final agentNameController =
      TextEditingController();
  final cityController =
      TextEditingController();
  final problemsController =
      TextEditingController();

  final ImagePicker imagePicker =
      ImagePicker();

  final AudioRecorder audioRecorder =
      AudioRecorder();

  final List<EvidenceFile> evidences =
      [];

  bool saving = false;
  bool recording = false;
  String? recordingPath;

  @override
  void initState() {
    super.initState();

    dateController.text =
        gregorianToJalali(
      DateTime.now(),
    );
  }

  Future<void>
      pickGalleryImages() async {
    try {
      final images =
          await imagePicker
              .pickMultiImage(
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
    } catch (_) {
      showMessage(
        'خطا در انتخاب عکس',
      );
    }
  }

  Future<void> takePhoto() async {
    try {
      final image =
          await imagePicker.pickImage(
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
      showMessage(
        'خطا در گرفتن عکس',
      );
    }
  }

  Future<void> pickFile() async {
    try {
      final result =
          await FilePicker.platform
              .pickFiles();

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final picked =
          result.files.first;

      if (picked.path == null) {
        showMessage(
          'فایل قابل دسترسی نیست',
        );
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

      await File(
        picked.path!,
      ).copy(
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
      showMessage(
        'خطا در انتخاب فایل',
      );
    }
  }

  Future<void>
      startRecording() async {
    try {
      final hasPermission =
          await audioRecorder
              .hasPermission();

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
          encoder:
              AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: recordingPath!,
      );

      if (mounted) {
        setState(() {
          recording = true;
        });
      }
    } catch (_) {
      showMessage(
        'خطا در شروع ضبط صدا',
      );
    }
  }

  Future<void>
      stopRecording() async {
    try {
      final path =
          await audioRecorder.stop();

      if (mounted) {
        setState(() {
          recording = false;
        });
      }

      if (path != null &&
          path.isNotEmpty) {
        evidences.add(
          EvidenceFile(
            path: path,
            type: 'audio',
            name: 'فایل صوتی',
          ),
        );

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

      showMessage(
        'خطا در ذخیره فایل صوتی',
      );
    }
  }

  Future<void> removeEvidence(
    int index,
  ) async {
    final evidence =
        evidences[index];

    try {
      final file =
          File(evidence.path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        evidences.removeAt(index);
      });
    }
  }

  void showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  Future<void> save() async {
    if (agentCodeController.text
        .trim()
        .isEmpty) {
      showMessage(
        'کد عامل را وارد کنید',
      );
      return;
    }

    setState(() {
      saving = true;
    });

    final inspection =
        Inspection(
      id: DateTime.now()
          .millisecondsSinceEpoch
          .toString(),
      date:
          dateController.text.trim(),
      agentCode:
          agentCodeController.text
              .trim(),
      agentName:
          agentNameController.text
              .trim(),
      city:
          cityController.text.trim(),
      problems:
          problemsController.text
              .trim(),
      evidences:
          List<EvidenceFile>.from(
        evidences,
      ),
    );

    await AppStorage.addInspection(
      inspection,
    );

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

  Widget evidenceSection() {
    return Card(
      color:
          const Color(0xFF101B2E),
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
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
                  Icons.attach_file,
                  color:
                      Color(0xFFC9A227),
                ),
                SizedBox(width: 8),
                Text(
                  'ثبت مستندات',
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
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        pickGalleryImages,
                    icon:
                        const Icon(
                      Icons.photo,
                    ),
                    label:
                        const Text(
                      'گالری',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        takePhoto,
                    icon:
                        const Icon(
                      Icons.camera_alt,
                    ),
                    label:
                        const Text(
                      'دوربین',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton.icon(
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
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        pickFile,
                    icon:
                        const Icon(
                      Icons
                          .insert_drive_file,
                    ),
                    label:
                        const Text(
                      'فایل',
                    ),
                  ),
                ),
              ],
            ),
            if (recording) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(
                    Icons
                        .fiber_manual_record,
                    color: Colors.red,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'در حال ضبط صدا...',
                    style:
                        TextStyle(
                      color:
                          Colors.redAccent,
                      fontWeight:
                          FontWeight.bold,
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
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(
                evidences.length,
                (index) {
                  final evidence =
                      evidences[index];

                  IconData icon;

                  if (evidence.type ==
                      'image') {
                    icon = Icons.image;
                  } else if (evidence.type ==
                      'audio') {
                    icon =
                        Icons.audiotrack;
                  } else {
                    icon = Icons
                        .insert_drive_file;
                  }
return ListTile(
  contentPadding: EdgeInsets.zero,
  leading: Icon(
    icon,
    color: const Color(0xFFC9A227),
  ),
  title: Text(
    evidence.name,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
  trailing: const Icon(
    Icons.open_in_new,
    color: Color(0xFFC9A227),
  ),
  onTap: () {
    if (evidence.type == 'image') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullImagePage(
            imagePath: evidence.path,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'فعلاً باز کردن این نوع مستند در این بخش فعال نیست',
          ),
        ),
      );
    }
  },
);
                    trailing:
                        IconButton(
                      icon:
                          const Icon(
                        Icons
                            .delete_outline,
                        color:
                            Colors
                                .redAccent,
                      ),
                      onPressed: () =>
                          removeEvidence(
                        index,
                      ),
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'ثبت بازرسی جدید',
        ),
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            AppTextField(
              controller:
                  dateController,
              label:
                  'تاریخ شمسی',
              icon:
                  Icons.calendar_month,
            ),
            AppTextField(
              controller:
                  agentCodeController,
              label:
                  'کد عامل *',
              icon:
                  Icons.numbers,
              keyboardType:
                  TextInputType.number,
            ),
            AppTextField(
              controller:
                  agentNameController,
              label:
                  'نام عامل',
              icon:
                  Icons.store,
            ),
            AppTextField(
              controller:
                  cityController,
              label:
                  'شهر',
              icon:
                  Icons.location_city,
            ),
            AppTextField(
              controller:
                  problemsController,
              label:
                  'شرح مشکلات',
              icon:
                  Icons.warning,
              maxLines: 5,
            ),
            evidenceSection(),
            const SizedBox(height: 4),
            SizedBox(
              width:
                  double.infinity,
              height: 52,
              child:
                  ElevatedButton.icon(
                onPressed:
                    saving
                        ? null
                        : save,
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),
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

class AppTextField
    extends StatelessWidget {
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
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: TextField(
        controller:
            controller,
        keyboardType:
            keyboardType,
        maxLines:
            maxLines,
        decoration:
            InputDecoration(
          labelText: label,
          prefixIcon:
              Icon(icon),
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

class ArchivePage
    extends StatefulWidget {
  const ArchivePage({
    super.key,
  });

  @override
  State<ArchivePage> createState() =>
      _ArchivePageState();
}

class _ArchivePageState
    extends State<ArchivePage> {
  List<Inspection> inspections =
      [];
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
        .where(
          (date) =>
              date.isNotEmpty,
        )
        .toSet()
        .toList();

    result.sort(
      (a, b) => b.compareTo(a),
    );

    return result;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('بایگانی'),
        actions: [
          IconButton(
            tooltip:
                'بازرسی‌های تکراری',
            icon:
                const Icon(Icons.repeat),
            onPressed: () {
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
          IconButton(
            tooltip: 'جستجو',
            icon:
                const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SearchArchivePage(
                    inspections:
                        inspections,
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
                        TextStyle(
                      fontSize: 18,
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  itemCount:
                      dates.length,
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
                      child:
                          ListTile(
                        leading:
                            const Icon(
                          Icons
                              .calendar_month,
                          color:
                              Color(
                            0xFFC9A227,
                          ),
                        ),
                        title:
                            Text(
                          date,
                          style:
                              const TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        subtitle:
                            Text(
                          '$count بازرسی',
                        ),
                        trailing:
                            const Icon(
                          Icons
                              .chevron_right,
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
// عملکرد روزانه
// =====================================================

class DailyPerformancePage
    extends StatefulWidget {
  const DailyPerformancePage({
    super.key,
  });

  @override
  State<DailyPerformancePage>
      createState() =>
          _DailyPerformancePageState();
}

class _DailyPerformancePageState
    extends State<DailyPerformancePage> {
  final dateController =
      TextEditingController();
  final totalController =
      TextEditingController();
  final problemController =
      TextEditingController();
  final cityController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    dateController.text =
        gregorianToJalali(
      DateTime.now(),
    );
  }

  @override
  void dispose() {
    dateController.dispose();
    totalController.dispose();
    problemController.dispose();
    cityController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final total =
        int.tryParse(
              totalController.text.trim(),
            ) ??
            0;

    final problems =
        int.tryParse(
              problemController.text.trim(),
            ) ??
            0;

    final prefs =
        await SharedPreferences
            .getInstance();

    final data = {
      'date':
          dateController.text.trim(),
      'total': total,
      'problems': problems,
      'city':
          cityController.text.trim(),
    };

    final old =
        prefs.getStringList(
              'daily_performance',
            ) ??
            [];

    old.insert(
      0,
      jsonEncode(data),
    );

    await prefs.setStringList(
      'daily_performance',
      old,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'عملکرد روزانه با موفقیت ثبت شد',
        ),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ثبت عملکرد روزانه',
        ),
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            AppTextField(
              controller:
                  dateController,
              label: 'تاریخ',
              icon:
                  Icons.calendar_month,
            ),
            AppTextField(
              controller:
                  totalController,
              label:
                  'تعداد کل بازرسی',
              icon:
                  Icons.assignment,
              keyboardType:
                  TextInputType.number,
            ),
            AppTextField(
              controller:
                  problemController,
              label:
                  'تعداد مشکلات',
              icon:
                  Icons.warning,
              keyboardType:
                  TextInputType.number,
            ),
            AppTextField(
              controller:
                  cityController,
              label: 'شهر',
              icon:
                  Icons.location_city,
            ),
            const SizedBox(
              height: 10,
            ),
            SizedBox(
              width:
                  double.infinity,
              height: 52,
              child:
                  ElevatedButton.icon(
                onPressed: save,
                icon:
                    const Icon(
                  Icons.save,
                ),
                label:
                    const Text(
                  'ثبت عملکرد',
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
// گزارش‌ها
// =====================================================

class ReportsPage
    extends StatefulWidget {
  const ReportsPage({
    super.key,
  });

  @override
  State<ReportsPage> createState() =>
      _ReportsPageState();
}

class _ReportsPageState
    extends State<ReportsPage> {
  List<Inspection> inspections =
      [];

  int dailyTotal = 0;
  int dailyProblems = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data =
        await AppStorage
            .getInspections();

    final prefs =
        await SharedPreferences
            .getInstance();

    final records =
        prefs.getStringList(
              'daily_performance',
            ) ??
            [];

    int total = 0;
    int problems = 0;

    for (final item in records) {
      try {
        final map =
            jsonDecode(item);

        total +=
            (map['total'] as num?)
                    ?.toInt() ??
                0;

        problems +=
            (map['problems'] as num?)
                    ?.toInt() ??
                0;
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      inspections = data;
      dailyTotal = total;
      dailyProblems = problems;
    });
  }

  Map<String, int> cityCounts() {
    final result =
        <String, int>{};

    for (final item in inspections) {
      final city =
          item.city.trim().isEmpty
              ? 'نامشخص'
              : item.city.trim();

      result[city] =
          (result[city] ?? 0) + 1;
    }

    return result;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final cities =
        cityCounts();

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('گزارش‌ها'),
      ),
      body:
          RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: [
            _ReportCard(
              title:
                  'تعداد کل بازرسی‌های ثبت‌شده',
              value:
                  inspections.length
                      .toString(),
              icon:
                  Icons
                      .assignment_turned_in,
            ),
            _ReportCard(
              title:
                  'مجموع عملکرد روزانه',
              value:
                  dailyTotal.toString(),
              icon:
                  Icons.today,
            ),
            _ReportCard(
              title:
                  'مجموع مشکلات ثبت‌شده',
              value:
                  dailyProblems
                      .toString(),
              icon:
                  Icons.warning,
            ),
            const SizedBox(
              height: 12,
            ),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Text(
                      'گزارش بر اساس شهر',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    if (cities.isEmpty)
                      const Text(
                        'اطلاعاتی ثبت نشده است',
                      )
                    else
                      ...cities.entries.map(
                        (entry) =>
                            ListTile(
                          leading:
                              const Icon(
                            Icons
                                .location_city,
                            color:
                                Color(
                              0xFFC9A227,
                            ),
                          ),
                          title:
                              Text(
                            entry.key,
                          ),
                          trailing:
                              Text(
                            '${entry.value} بازرسی',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard
    extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          size: 38,
          color:
              const Color(0xFFC9A227),
        ),
        title:
            Text(title),
        trailing:
            Text(
          value,
          style:
              const TextStyle(
            fontSize: 22,
            fontWeight:
                FontWeight.bold,
            color:
                Color(0xFFC9A227),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// تنظیمات
// =====================================================

class SettingsPage
    extends StatefulWidget {
  const SettingsPage({
    super.key,
  });

  @override
  State<SettingsPage> createState() =>
      _SettingsPageState();
}

class _SettingsPageState
    extends State<SettingsPage> {
  final nameController =
      TextEditingController(
    text: 'رضا طاحونی',
  );

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> saveName() async {
    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      'inspector_name',
      nameController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content:
            Text('تنظیمات ذخیره شد'),
      ),
    );
  }

  Future<void>
      changePassword() async {
    final controller =
        TextEditingController();

    final password =
        await showDialog<String>(
      context: context,
      builder: (context) =>
          AlertDialog(
        title: const Text(
          'تغییر رمز ورود',
        ),
        content: TextField(
          controller:
              controller,
          obscureText: true,
          keyboardType:
              TextInputType.number,
          decoration:
              const InputDecoration(
            labelText:
                'رمز جدید',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
            ),
            child:
                const Text(
              'انصراف',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(
                context,
                controller.text.trim(),
              );
            },
            child:
                const Text(
              'ذخیره',
            ),
          ),
        ],
      ),
    );

    controller.dispose();

    if (password == null ||
        password.isEmpty) {
      return;
    }

    final prefs =
        await SharedPreferences
            .getInstance();

    await prefs.setString(
      'app_password',
      password,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content:
            Text('رمز جدید ذخیره شد'),
      ),
    );
  }

  Future<void>
      clearInspections() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
        title: const Text(
          'حذف اطلاعات',
        ),
        content:
            const Text(
          'آیا از حذف تمام بازرسی‌ها مطمئن هستید؟',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              false,
            ),
            child:
                const Text(
              'انصراف',
            ),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(
              context,
              true,
            ),
            child:
                const Text(
              'حذف',
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await AppStorage
        .saveInspections([]);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'اطلاعات بازرسی‌ها حذف شد',
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('تنظیمات'),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          const Text(
            'مشخصات بازرس',
            style:
                TextStyle(
              fontSize: 19,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 12,
          ),
          AppTextField(
            controller:
                nameController,
            label:
                'نام بازرس',
            icon:
                Icons.person,
          ),
          SizedBox(
            width:
                double.infinity,
            height: 50,
            child:
                ElevatedButton(
              onPressed:
                  saveName,
              child:
                  const Text(
                'ذخیره نام',
              ),
            ),
          ),
          const SizedBox(
            height: 24,
          ),
          Card(
            child: ListTile(
              leading:
                  const Icon(
                Icons.lock,
              ),
              title:
                  const Text(
                'تغییر رمز ورود',
              ),
              trailing:
                  const Icon(
                Icons.chevron_left,
              ),
              onTap:
                  changePassword,
            ),
          ),
          Card(
            child: ListTile(
              leading:
                  const Icon(
                Icons.delete_forever,
                color:
                    Colors.redAccent,
              ),
              title:
                  const Text(
                'حذف تمام بازرسی‌ها',
              ),
              trailing:
                  const Icon(
                Icons.chevron_left,
              ),
              onTap:
                  clearInspections,
            ),
          ),
          const SizedBox(
            height: 20,
          ),
          const Center(
            child: Text(
              'سامانه مدیریت بازرسی',
              style:
                  TextStyle(
                color:
                    Color(0xFFC9A227),
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// بایگانی روزانه
// =====================================================

class DailyArchivePage
    extends StatelessWidget {
  final String date;
  final List<Inspection> inspections;

  const DailyArchivePage({
    super.key,
    required this.date,
    required this.inspections,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final daily = inspections
        .where(
          (item) => item.date == date,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title:
            Text('بازرسی‌های $date'),
      ),
      body: daily.isEmpty
          ? const Center(
              child: Text(
                'بازرسی‌ای برای این تاریخ وجود ندارد',
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.all(12),
              itemCount:
                  daily.length,
              itemBuilder:
                  (context, index) {
                final item =
                    daily[index];

                return Card(
                  child: ListTile(
                    leading:
                        const CircleAvatar(
                      child:
                          Icon(
                        Icons.assignment,
                      ),
                    ),
                    title:
                        Text(
                      item.agentCode
                              .isEmpty
                          ? 'بدون کد عامل'
                          : item.agentCode,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    subtitle:
                        Text(
                      [
                        if (item.agentName
                            .isNotEmpty)
                          'عامل: ${item.agentName}',
                        if (item.city
                            .isNotEmpty)
                          'شهر: ${item.city}',
                        if (item.problems
                            .isNotEmpty)
                          'مشکلات: ${item.problems}',
                      ].join('\n'),
                    ),
                    isThreeLine:
                        true,
                    trailing:
                        const Icon(
                      Icons
                          .chevron_right,
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
    );
  }
}
class FullImagePage extends StatelessWidget {
  final String imagePath;

  const FullImagePage({
    super.key,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مشاهده تصویر'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return const Center(
                child: Text(
                  'تصویر قابل نمایش نیست',
                ),
              );
            },
          ),
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
  State<SearchArchivePage>
      createState() =>
          _SearchArchivePageState();
}

class _SearchArchivePageState
    extends State<SearchArchivePage> {
  final searchController =
      TextEditingController();

  List<Inspection> results =
      [];

  @override
  void initState() {
    super.initState();
    results =
        widget.inspections;
  }

  void search(String value) {
    final query =
        value.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        results =
            widget.inspections;
      } else {
        results =
            widget.inspections
                .where(
                  (item) {
                    return item.agentCode
                            .toLowerCase()
                            .contains(query) ||
                        item.agentName
                            .toLowerCase()
                            .contains(query) ||
                        item.city
                            .toLowerCase()
                            .contains(query) ||
                        item.date
                            .toLowerCase()
                            .contains(query) ||
                        item.problems
                            .toLowerCase()
                            .contains(query);
                  },
                )
                .toList();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'جستجوی بایگانی',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(12),
            child: TextField(
              controller:
                  searchController,
              onChanged:
                  search,
              decoration:
                  const InputDecoration(
                labelText:
                    'کد عامل، نام، شهر یا تاریخ',
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
                      'موردی پیدا نشد',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        results.length,
                    itemBuilder:
                        (context, index) {
                      final item =
                          results[index];

                      return Card(
                        margin:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        child:
                            ListTile(
                          leading:
                              const Icon(
                            Icons.assignment,
                            color:
                                Color(
                              0xFFC9A227,
                            ),
                          ),
                          title:
                              Text(
                            item.agentCode
                                    .isEmpty
                                ? 'بدون کد عامل'
                                : item.agentCode,
                          ),
                          subtitle:
                              Text(
                            '${item.date}'
                            '${item.city.isEmpty ? '' : ' | ${item.city}'}',
                          ),
                          trailing:
                              const Icon(
                            Icons
                                .chevron_right,
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
// بازرسی‌های تکراری
// =====================================================

class RepeatedInspectionsPage
    extends StatelessWidget {
  final List<Inspection> inspections;

  const RepeatedInspectionsPage({
    super.key,
    required this.inspections,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final groups =
        <String, List<Inspection>>{};

    for (final item
        in inspections) {
      final key =
          item.agentCode.trim();

      if (key.isEmpty) continue;

      groups.putIfAbsent(
        key,
        () => [],
      ).add(item);
    }

    final repeated =
        groups.entries
            .where(
              (entry) =>
                  entry.value.length >
                  1,
            )
            .toList();

    repeated.sort(
      (a, b) => b.value.length
          .compareTo(
        a.value.length,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'بازرسی‌های تکراری',
        ),
      ),
      body: repeated.isEmpty
          ? const Center(
              child: Text(
                'بازرسی تکراری پیدا نشد',
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.all(12),
              itemCount:
                  repeated.length,
              itemBuilder:
                  (context, index) {
                final entry =
                    repeated[index];

                return Card(
                  child:
                      ExpansionTile(
                    leading:
                        const Icon(
                      Icons.repeat,
                      color:
                          Color(
                        0xFFC9A227,
                      ),
                    ),
                    title:
                        Text(
                      'کد عامل: ${entry.key}',
                    ),
                    subtitle:
                        Text(
                      '${entry.value.length} بار بازرسی',
                    ),
                    children:
                        entry.value
                            .map(
                      (item) {
                        return ListTile(
                          title:
                              Text(
                            item.date,
                          ),
                          subtitle:
                              Text(
                            [
                              if (item
                                  .agentName
                                  .isNotEmpty)
                                item.agentName,
                              if (item
                                  .city
                                  .isNotEmpty)
                                item.city,
                            ].join(
                              ' - ',
                            ),
                          ),
                          trailing:
                              const Icon(
                            Icons
                                .chevron_right,
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
                        );
                      },
                    )
                            .toList(),
                  ),
                );
              },
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'جزئیات بازرسی',
        ),
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            _infoCard(
              icon:
                  Icons.calendar_month,
              title: 'تاریخ',
              value:
                  inspection.date,
            ),
            _infoCard(
              icon:
                  Icons.numbers,
              title: 'کد عامل',
              value: inspection
                      .agentCode
                      .isEmpty
                  ? 'ثبت نشده'
                  : inspection
                      .agentCode,
            ),
            _infoCard(
              icon:
                  Icons.store,
              title: 'نام عامل',
              value: inspection
                      .agentName
                      .isEmpty
                  ? 'ثبت نشده'
                  : inspection
                      .agentName,
            ),
            _infoCard(
              icon:
                  Icons.location_city,
              title: 'شهر',
              value: inspection
                      .city
                      .isEmpty
                  ? 'ثبت نشده'
                  : inspection.city,
            ),
            _infoCard(
              icon:
                  Icons.warning,
              title:
                  'شرح مشکلات',
              value: inspection
                      .problems
                      .isEmpty
                  ? 'مشکلی ثبت نشده'
                  : inspection
                      .problems,
            ),
            const SizedBox(
              height: 8,
            ),
            Card(
              color:
                  const Color(0xFF101B2E),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          color:
                              Color(
                            0xFFC9A227,
                          ),
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'مستندات',
                          style:
                              TextStyle(
                            color:
                                Color(
                              0xFFC9A227,
                            ),
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    if (inspection
                        .evidences
                        .isEmpty)
                      const Text(
                        'مستندی برای این بازرسی ثبت نشده است.',
                      )
                    else
                      ...inspection
                          .evidences
                          .map(
                        (evidence) {
                          IconData icon;

                          if (evidence
                                  .type ==
                              'image') {
                            icon =
                                Icons.image;
                          } else if (evidence
                                  .type ==
                              'audio') {
                            icon =
                                Icons
                                    .audiotrack;
                          } else {
                            icon =
                                Icons
                                    .insert_drive_file;
                          }

                          return ListTile(
                            contentPadding:
                                EdgeInsets
                                    .zero,
                            leading:
                                Icon(
                              icon,
                              color:
                                  const Color(
                                0xFFC9A227,
                              ),
                            ),
                            title:
                                Text(
                              evidence
                                  .name,
                              maxLines:
                                  1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      color:
          const Color(0xFF101B2E),
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color:
              const Color(0xFFC9A227),
        ),
        title:
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
        subtitle:
            Padding(
          padding:
              const EdgeInsets.only(
            top: 5,
          ),
          child:
              Text(
            value,
            style:
                const TextStyle(
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
