import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================
// مدل مستند
// =====================================================

class EvidenceFile {
  final String name;
  final String path;
  final String type;

  const EvidenceFile({
    required this.name,
    required this.path,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'type': type,
    };
  }

  factory EvidenceFile.fromMap(Map<String, dynamic> map) {
    return EvidenceFile(
      name: (map['name'] ?? '').toString(),
      path: (map['path'] ?? '').toString(),
      type: (map['type'] ?? 'file').toString(),
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

  const Inspection({
    required this.id,
    required this.date,
    required this.agentCode,
    required this.agentName,
    required this.city,
    required this.problems,
    required this.evidences,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'agentCode': agentCode,
      'agentName': agentName,
      'city': city,
      'problems': problems,
      'evidences':
          evidences.map((e) => e.toMap()).toList(),
    };
  }

  factory Inspection.fromMap(Map<String, dynamic> map) {
    final rawEvidences = map['evidences'];

    final List<EvidenceFile> loadedEvidences = [];

    if (rawEvidences is List) {
      for (final item in rawEvidences) {
        if (item is Map) {
          loadedEvidences.add(
            EvidenceFile.fromMap(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return Inspection(
      id: (map['id'] ?? '').toString(),
      date: (map['date'] ?? '').toString(),
      agentCode: (map['agentCode'] ?? '').toString(),
      agentName: (map['agentName'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      problems: (map['problems'] ?? '').toString(),
      evidences: loadedEvidences,
    );
  }
}

// =====================================================
// ذخیره‌سازی اطلاعات
// =====================================================

class AppStorage {
  static const String _inspectionsKey = 'inspections';
  static const String _passwordKey = 'app_password';
  static const String _inspectorNameKey = 'inspector_name';

  static Future<SharedPreferences> _prefs() async {
    return SharedPreferences.getInstance();
  }

  // ---------------------------------------------------
  // بازرسی‌ها
  // ---------------------------------------------------

  static Future<List<Inspection>> getInspections() async {
    final prefs = await _prefs();

    final raw = prefs.getString(_inspectionsKey);

    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => Inspection.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> saveInspections(
    List<Inspection> inspections,
  ) async {
    final prefs = await _prefs();

    final data = inspections
        .map((item) => item.toMap())
        .toList();

    return prefs.setString(
      _inspectionsKey,
      jsonEncode(data),
    );
  }

  static Future<bool> addInspection(
    Inspection inspection,
  ) async {
    final inspections = await getInspections();

    inspections.add(inspection);

    return saveInspections(inspections);
  }

  static Future<bool> deleteInspection(
    String id,
  ) async {
    final inspections = await getInspections();

    inspections.removeWhere(
      (item) => item.id == id,
    );

    return saveInspections(inspections);
  }

  // ---------------------------------------------------
  // نام بازرس
  // ---------------------------------------------------

  static Future<String> getInspectorName() async {
    final prefs = await _prefs();

    return prefs.getString(
          _inspectorNameKey,
        ) ??
        'رضا طاحونی';
  }

  static Future<bool> saveInspectorName(
    String name,
  ) async {
    final prefs = await _prefs();

    return prefs.setString(
      _inspectorNameKey,
      name,
    );
  }

  // ---------------------------------------------------
  // رمز عبور
  // ---------------------------------------------------

  static Future<String> getPassword() async {
    final prefs = await _prefs();

    return prefs.getString(
          _passwordKey,
        ) ??
        '1234';
  }

  static Future<bool> savePassword(
    String password,
  ) async {
    final prefs = await _prefs();

    return prefs.setString(
      _passwordKey,
      password,
    );
  }
}

// =====================================================
// تبدیل تاریخ میلادی به شمسی
// =====================================================

String gregorianToJalali(DateTime date) {
  int gy = date.year;
  int gm = date.month;
  int gd = date.day;

  final List<int> gDaysInMonth = [
    0,
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

  final List<int> jDaysInMonth = [
    0,
    31,
    31,
    31,
    31,
    31,
    31,
    30,
    30,
    30,
    30,
    30,
    29,
  ];

  int gy2 = gy - 1600;
  int gm2 = gm - 1;
  int gd2 = gd - 1;

  int gDayNo =
      365 * gy2 +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400);

  for (int i = 0; i < gm2; i++) {
    gDayNo += gDaysInMonth[i + 1];
  }

  if (gm > 2 &&
      ((gy % 4 == 0 && gy % 100 != 0) ||
          gy % 400 == 0)) {
    gDayNo++;
  }

  gDayNo += gd2;

  int jDayNo = gDayNo - 79;

  int jNp = jDayNo ~/ 12053;
  jDayNo %= 12053;

  int jy = 979 + (33 * jNp);

  int cycle = jDayNo ~/ 1461;
  jDayNo %= 1461;

  if (jDayNo >= 366) {
    jy += ((jDayNo - 1) ~/ 365);
    jDayNo = (jDayNo - 1) % 365;
  }

  int jm;
  int jd;

  if (jDayNo < 186) {
    jm = 1 + (jDayNo ~/ 31);
    jd = 1 + (jDayNo % 31);
  } else {
    jm = 7 + ((jDayNo - 186) ~/ 30);
    jd = 1 + ((jDayNo - 186) % 30);
  }

  return '$jy/${jm.toString().padLeft(2, '0')}/${jd.toString().padLeft(2, '0')}';
}

// =====================================================
// تبدیل ارقام فارسی و عربی به انگلیسی
// =====================================================

String normalizeDigits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const english = '0123456789';

  var result = value;

  for (int i = 0; i < 10; i++) {
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

// =====================================================
// برنامه اصلی
// =====================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const InspectionManagerApp(),
  );
}

// =====================================================
// اپلیکیشن
// =====================================================

class InspectionManagerApp
    extends StatelessWidget {
  const InspectionManagerApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'سامانه مدیریت بازرسی',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
            const Color(0xFF0B1220),
        colorScheme: ColorScheme.fromSeed(
          seedColor:
              const Color(0xFFC9A227),
          brightness: Brightness.dark,
        ),
        appBarTheme:
            const AppBarTheme(
          backgroundColor:
              Color(0xFF101B2E),
          foregroundColor:
              Colors.white,
          centerTitle: true,
        ),
        cardTheme:
            const CardThemeData(
          color: Color(0xFF162238),
          elevation: 3,
          margin: EdgeInsets.only(
            bottom: 12,
          ),
        ),
        inputDecorationTheme:
            const InputDecorationTheme(
          filled: true,
          fillColor:
              Color(0xFF101B2E),
          border:
              OutlineInputBorder(),
          enabledBorder:
              OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.white24,
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderSide: BorderSide(
              color: Color(0xFFC9A227),
              width: 2,
            ),
          ),
          labelStyle:
              TextStyle(
            color: Colors.white70,
          ),
        ),
        elevatedButtonTheme:
            ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                const Color(0xFFC9A227),
            foregroundColor:
                Colors.black,
            minimumSize:
                const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
        ),
        outlinedButtonTheme:
            OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor:
                Colors.white,
            side:
                const BorderSide(
              color: Color(0xFFC9A227),
            ),
            minimumSize:
                const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// =====================================================
// ورود
// =====================================================

class LoginPage
    extends StatefulWidget {
  const LoginPage({
    super.key,
  });

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState
    extends State<LoginPage> {
  final passwordController =
      TextEditingController();

  bool obscurePassword = true;
  bool loading = false;

  Future<void> login() async {
    final password =
        passwordController.text.trim();

    if (password.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('رمز عبور را وارد کنید'),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    final savedPassword =
        await AppStorage.getPassword();

    if (!mounted) return;

    if (password == savedPassword) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const HomePage(),
        ),
      );
    } else {
      setState(() {
        loading = false;
      });

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xFFC9A227),
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield,
                    size: 58,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'سامانه مدیریت بازرسی',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color:
                        Color(0xFFC9A227),
                    fontSize: 25,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'ورود به سامانه',
                  style: TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 32),

                TextField(
                  controller:
                      passwordController,
                  obscureText:
                      obscurePassword,
                  onSubmitted: (_) =>
                      login(),
                  decoration:
                      InputDecoration(
                    labelText:
                        'رمز عبور',
                    prefixIcon:
                        const Icon(
                      Icons.lock,
                    ),
                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword =
                              !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons
                                .visibility_off,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        loading
                            ? null
                            : login,
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.black,
                            ),
                          )
                        : const Icon(
                            Icons.login,
                          ),
                    label: Text(
                      loading
                          ? 'در حال ورود...'
                          : 'ورود',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// صفحه اصلی
// =====================================================

class HomePage
    extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState
    extends State<HomePage> {
  String inspectorName =
      'رضا طاحونی';

  @override
  void initState() {
    super.initState();
    _loadInspectorName();
  }

  Future<void> _loadInspectorName() async {
    final name =
        await AppStorage.getInspectorName();

    if (!mounted) return;

    setState(() {
      inspectorName =
          name.trim().isEmpty
              ? 'رضا طاحونی'
              : name;
    });
  }

  Future<void> _openAddInspection() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const AddInspectionPage(),
      ),
    );

    if (!mounted) return;

    setState(() {});
  }

  Widget menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF101B2E),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFFC9A227),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.black,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color:
                    Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سامانه مدیریت بازرسی',
        ),
        actions: [
          IconButton(
            tooltip: 'تنظیمات',
            icon: const Icon(
              Icons.settings,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const SettingsPage(),
                ),
              );

              if (!mounted) return;

              _loadInspectorName();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh:
            _loadInspectorName,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: [
            Card(
              color:
                  const Color(0xFF101B2E),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          Color(0xFFC9A227),
                      child: Icon(
                        Icons.person,
                        color:
                            Colors.black,
                        size: 30,
                      ),
                    ),
                    const SizedBox(
                      width: 14,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Text(
                            'بازرس',
                            style:
                                TextStyle(
                              color:
                                  Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            inspectorName,
                            style:
                                const TextStyle(
                              color:
                                  Color(0xFFC9A227),
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            menuCard(
              icon:
                  Icons.add_task,
              title:
                  'ثبت بازرسی جدید',
              subtitle:
                  'ثبت اطلاعات و مستندات بازرسی',
              onTap:
                  _openAddInspection,
            ),

            menuCard(
              icon:
                  Icons.archive,
              title:
                  'بایگانی',
              subtitle:
                  'مشاهده و جستجوی بازرسی‌های ثبت‌شده',
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

            menuCard(
              icon:
                  Icons.bar_chart,
              title:
                  'آمار و گزارش‌ها',
              subtitle:
                  'گزارش روزانه، ماهانه و آمار شهرها',
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

            menuCard(
              icon:
                  Icons.today,
              title:
                  'ثبت عملکرد روزانه',
              subtitle:
                  'مدیریت عملکرد روزانه بازرس',
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
          ],
        ),
      ),
    );
  }
}

// =====================================================
// ثبت بازرسی
// =====================================================

class AddInspectionPage
    extends StatefulWidget {
  const AddInspectionPage({
    super.key,
  });

  @override
  State<AddInspectionPage> createState() =>
      _AddInspectionPageState();
}

class _AddInspectionPageState
    extends State<AddInspectionPage> {
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

  final AudioRecorder recorder =
      AudioRecorder();

  List<EvidenceFile> evidences = [];

  bool recording = false;
  bool saving = false;

  String? recordingPath;

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
    agentCodeController.dispose();
    agentNameController.dispose();
    cityController.dispose();
    problemsController.dispose();
    recorder.dispose();
    super.dispose();
  }

  Future<Directory> _evidenceDirectory() async {
    final base =
        await getApplicationDocumentsDirectory();

    final directory = Directory(
      '${base.path}/inspection_evidences',
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive: true,
      );
    }

    return directory;
  }

  Future<String> _copyEvidenceFile(
    String sourcePath,
    String fileName,
  ) async {
    final directory =
        await _evidenceDirectory();

    final timestamp =
        DateTime.now().millisecondsSinceEpoch;

    final safeName =
        fileName.trim().isEmpty
            ? 'evidence_$timestamp'
            : fileName;

    final destination =
        '${directory.path}/$timestamp-$safeName';

    final source =
        File(sourcePath);

    final copied =
        await source.copy(destination);

    return copied.path;
  }

  Future<void> pickGalleryImages() async {
    try {
      final images =
          await imagePicker.pickMultiImage(
        imageQuality: 90,
      );

      for (final image in images) {
        final copiedPath =
            await _copyEvidenceFile(
          image.path,
          image.name,
        );

        evidences.add(
          EvidenceFile(
            name: image.name,
            path: copiedPath,
            type: 'image',
          ),
        );
      }

      if (!mounted) return;

      setState(() {});
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('انتخاب تصاویر انجام نشد'),
        ),
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

      final copiedPath =
          await _copyEvidenceFile(
        image.path,
        image.name,
      );

      evidences.add(
        EvidenceFile(
          name: image.name,
          path: copiedPath,
          type: 'image',
        ),
      );

      if (!mounted) return;

      setState(() {});
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('گرفتن عکس انجام نشد'),
        ),
      );
    }
  }

  Future<void> startRecording() async {
    try {
      final hasPermission =
          await recorder.hasPermission();

      if (!hasPermission) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('دسترسی ضبط صدا داده نشده است'),
          ),
        );
        return;
      }

      final directory =
          await _evidenceDirectory();

      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      recordingPath =
          '${directory.path}/voice_$timestamp.m4a';

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
        ),
        path: recordingPath!,
      );

      if (!mounted) return;

      setState(() {
        recording = true;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('شروع ضبط صدا انجام نشد'),
        ),
      );
    }
  }

  Future<void> stopRecording() async {
    try {
      final path =
          await recorder.stop();

      if (!mounted) return;

      setState(() {
        recording = false;
      });

      if (path == null ||
          path.trim().isEmpty) {
        return;
      }

      final fileName =
          'ضبط صدا ${DateTime.now().millisecondsSinceEpoch}.m4a';

      evidences.add(
        EvidenceFile(
          name: fileName,
          path: path,
          type: 'audio',
        ),
      );

      recordingPath = null;

      setState(() {});
    } catch (_) {
      if (!mounted) return;

      setState(() {
        recording = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('پایان ضبط صدا انجام نشد'),
        ),
      );
    }
  }

  Future<void> pickFile() async {
    try {
      final result =
          await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result == null) return;

      for (final picked in result.files) {
        final path = picked.path;

        if (path == null ||
            path.trim().isEmpty) {
          continue;
        }

        final copiedPath =
            await _copyEvidenceFile(
          path,
          picked.name,
        );

        evidences.add(
          EvidenceFile(
            name: picked.name,
            path: copiedPath,
            type: 'file',
          ),
        );
      }

      if (!mounted) return;

      setState(() {});
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('انتخاب فایل انجام نشد'),
        ),
      );
    }
  }

  void removeEvidence(int index) {
    if (index < 0 ||
        index >= evidences.length) {
      return;
    }

    setState(() {
      evidences.removeAt(index);
    });
  }

  Future<void> save() async {
    if (saving) return;

    final agentCode =
        normalizeDigits(
      agentCodeController.text.trim(),
    );

    if (agentCode.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('کد عامل را وارد کنید'),
        ),
      );
      return;
    }

    if (dateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('تاریخ را وارد کنید'),
        ),
      );
      return;
    }

    if (recording) {
      await stopRecording();
    }

    setState(() {
      saving = true;
    });

    try {
      final inspection =
          Inspection(
        id: DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        date:
            dateController.text.trim(),
        agentCode: agentCode,
        agentName:
            agentNameController.text.trim(),
        city:
            cityController.text.trim(),
        problems:
            problemsController.text.trim(),
        evidences:
            List<EvidenceFile>.from(
          evidences,
        ),
      );

      final success =
          await AppStorage.addInspection(
        inspection,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('بازرسی با موفقیت ثبت شد'),
          ),
        );

        Navigator.pop(context);
      } else {
        setState(() {
          saving = false;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('ذخیره بازرسی انجام نشد'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('خطا در ثبت بازرسی'),
        ),
      );
    }
  }

  Widget evidenceSection() {
    return Card(
      color: const Color(0xFF101B2E),
      margin:
          const EdgeInsets.only(bottom: 12),
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
                    icon: const Icon(
                      Icons.photo,
                    ),
                    label:
                        const Text('گالری'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        takePhoto,
                    icon: const Icon(
                      Icons.camera_alt,
                    ),
                    label:
                        const Text('دوربین'),
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
                    onPressed: recording
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
                        const Text('فایل'),
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
                    icon =
                        Icons.image;
                  } else if (evidence
                          .type ==
                      'audio') {
                    icon =
                        Icons.audiotrack;
                  } else {
                    icon = Icons
                        .insert_drive_file;
                  }

                  return ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    leading: Icon(
                      icon,
                      color:
                          const Color(
                        0xFFC9A227,
                      ),
                    ),
                    title: Text(
                      evidence.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                    trailing:
                        IconButton(
                      icon:
                          const Icon(
                        Icons
                            .delete_outline,
                        color:
                            Colors.redAccent,
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('ثبت بازرسی جدید'),
      ),
      body: SingleChildScrollView(
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
                          strokeWidth:
                              2,
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
  Widget build(BuildContext context) {
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
    try {
      final data =
          await AppStorage
              .getInspections();

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

  String normalizeDigits(
    String value,
  ) {
    const persian =
        '۰۱۲۳۴۵۶۷۸۹';
    const arabic =
        '٠١٢٣٤٥٦٧٨٩';
    const english =
        '0123456789';

    var result = value;

    for (var i = 0;
        i < 10;
        i++) {
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

  String getMonth(
    String date,
  ) {
    final parts =
        date.trim().split('/');

    if (parts.length < 2) {
      return '';
    }

    final year =
        normalizeDigits(
      parts[0],
    );

    final month =
        normalizeDigits(
      parts[1],
    ).padLeft(2, '0');

    if (year.isEmpty ||
        month.isEmpty) {
      return '';
    }

    return '$year/$month';
  }

  int monthSortKey(
    String month,
  ) {
    final parts =
        month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year =
        int.tryParse(parts[0]) ??
            0;

    final monthNumber =
        int.tryParse(parts[1]) ??
            0;

    return (year * 100) +
        monthNumber;
  }

  String monthTitle(
    String month,
  ) {
    final parts =
        month.split('/');

    if (parts.length != 2) {
      return month;
    }

    final year =
        parts[0];

    final monthNumber =
        int.tryParse(
              parts[1],
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
  }

  List<String> get months {
    final result =
        inspections
            .map(
              (item) =>
                  getMonth(item.date),
            )
            .where(
              (month) =>
                  month.isNotEmpty,
            )
            .toSet()
            .toList();

    result.sort(
      (a, b) =>
          monthSortKey(b)
              .compareTo(
            monthSortKey(a),
          ),
    );

    return result;
  }

  int countForMonth(
    String month,
  ) {
    return inspections
        .where(
          (item) =>
              getMonth(item.date) ==
              month,
        )
        .length;
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
                const Icon(
              Icons.repeat,
            ),
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
            tooltip:
                'جستجو',
            icon:
                const Icon(
              Icons.search,
            ),
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
          : months.isEmpty
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
                      const EdgeInsets
                          .all(12),
                  itemCount:
                      months.length,
                  itemBuilder:
                      (context, index) {
                    final month =
                        months[index];

                    final count =
                        countForMonth(
                      month,
                    );

                    return Card(
                      child:
                          ListTile(
                        leading:
                            const Icon(
                          Icons.folder,
                          color:
                              Color(
                            0xFFC9A227,
                          ),
                          size: 32,
                        ),
                        title:
                            Text(
                          monthTitle(
                            month,
                          ),
                          style:
                              const TextStyle(
                            fontSize: 18,
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
                              builder:
                                  (_) =>
                                      MonthArchivePage(
                                month:
                                    month,
                                monthTitleText:
                                    monthTitle(
                                  month,
                                ),
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
// بایگانی یک ماه
// =====================================================

class MonthArchivePage
    extends StatelessWidget {
  final String month;
  final String monthTitleText;
  final List<Inspection>
      inspections;

  const MonthArchivePage({
    super.key,
    required this.month,
    required this.monthTitleText,
    required this.inspections,
  });

  String normalizeDigits(
    String value,
  ) {
    const persian =
        '۰۱۲۳۴۵۶۷۸۹';
    const arabic =
        '٠١٢٣٤٥٦٧٨٩';
    const english =
        '0123456789';

    var result = value;

    for (var i = 0;
        i < 10;
        i++) {
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

  String getMonth(
    String date,
  ) {
    final parts =
        date.trim().split('/');

    if (parts.length < 2) {
      return '';
    }

    return '${normalizeDigits(parts[0])}/${normalizeDigits(parts[1]).padLeft(2, '0')}';
  }

  String getDay(
    String date,
  ) {
    final parts =
        date.trim().split('/');

    if (parts.length < 3) {
      return date;
    }

    return normalizeDigits(
      parts[2],
    ).padLeft(2, '0');
  }

  int daySortKey(
    String date,
  ) {
    final parts =
        date.split('/');

    if (parts.length < 3) {
      return 0;
    }

    final year =
        int.tryParse(parts[0]) ??
            0;

    final monthNumber =
        int.tryParse(parts[1]) ??
            0;

    final day =
        int.tryParse(parts[2]) ??
            0;

    return (year * 10000) +
        (monthNumber * 100) +
        day;
  }

  List<String> get dates {
    final result = inspections
        .where(
          (item) =>
              getMonth(item.date) ==
              month,
        )
        .map(
          (item) => item.date,
        )
        .where(
          (date) =>
              date.isNotEmpty,
        )
        .toSet()
        .toList();

    result.sort(
      (a, b) =>
          daySortKey(b)
              .compareTo(
            daySortKey(a),
          ),
    );

    return result;
  }

  int countForDate(
    String date,
  ) {
    return inspections
        .where(
          (item) =>
              item.date == date,
        )
        .length;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(monthTitleText),
      ),
      body: dates.isEmpty
          ? const Center(
              child: Text(
                'در این ماه بازرسی‌ای ثبت نشده است',
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets
                      .all(12),
              itemCount:
                  dates.length,
              itemBuilder:
                  (context, index) {
                final date =
                    dates[index];

                final count =
                    countForDate(
                  date,
                );

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
                      size: 30,
                    ),
                    title:
                        Text(
                      'روز ${getDay(date)}',
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                    subtitle:
                        Text(
                      '$date  •  $count بازرسی',
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
                            date:
                                date,
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
}// =====================================================
// مدل مستندات
// =====================================================

class EvidenceFile {
  final String name;
  final String path;
  final String type;

  const EvidenceFile({
    required this.name,
    required this.path,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'type': type,
    };
  }

  factory EvidenceFile.fromJson(
    Map<String, dynamic> json,
  ) {
    return EvidenceFile(
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      type: json['type']?.toString() ?? 'file',
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

  const Inspection({
    required this.id,
    required this.date,
    required this.agentCode,
    required this.agentName,
    required this.city,
    required this.problems,
    this.evidences = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'agentCode': agentCode,
      'agentName': agentName,
      'city': city,
      'problems': problems,
      'evidences': evidences
          .map((evidence) => evidence.toJson())
          .toList(),
    };
  }

  factory Inspection.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawEvidences = json['evidences'];

    List<EvidenceFile> loadedEvidences = [];

    if (rawEvidences is List) {
      loadedEvidences = rawEvidences
          .whereType<Map>()
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
      evidences: loadedEvidences,
    );
  }
}

// =====================================================
// ذخیره‌سازی اطلاعات
// =====================================================

class AppStorage {
  static const String _inspectionsKey =
      'inspections';

  static Future<List<Inspection>> getInspections() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_inspectionsKey);

    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
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
        .map((item) => item.toJson())
        .toList();

    await prefs.setString(
      _inspectionsKey,
      jsonEncode(data),
    );
  }

  static Future<void> addInspection(
    Inspection inspection,
  ) async {
    final inspections =
        await getInspections();

    inspections.add(inspection);

    await saveInspections(inspections);
  }

  static Future<void> deleteInspection(
    String id,
  ) async {
    final inspections =
        await getInspections();

    inspections.removeWhere(
      (item) => item.id == id,
    );

    await saveInspections(inspections);
  }
}

// =====================================================
// تبدیل اعداد فارسی و عربی به انگلیسی
// =====================================================

String normalizeDigits(String value) {
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

// =====================================================
// تبدیل تاریخ میلادی به شمسی
// =====================================================

String gregorianToJalali(DateTime date) {
  int gy = date.year;
  int gm = date.month;
  int gd = date.day;

  final gDaysInMonth = [
    0,
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

  final jDaysInMonth = [
    0,
    31,
    31,
    31,
    31,
    31,
    31,
    30,
    30,
    30,
    30,
    30,
    29,
  ];

  int gy2 = gy - 1600;
  int gm2 = gm - 1;
  int gd2 = gd - 1;

  int gDayNo =
      365 * gy2 +
      ((gy2 + 3) ~/ 4) -
      ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400);

  for (int i = 0; i < gm2; i++) {
    gDayNo += gDaysInMonth[i + 1];
  }

  if (gm2 > 1 &&
      ((gy % 4 == 0 && gy % 100 != 0) ||
          gy % 400 == 0)) {
    gDayNo++;
  }

  gDayNo += gd2;

  int jDayNo = gDayNo - 79;

  int jNp = jDayNo ~/ 12053;
  int jYear = 979 + (33 * jNp);

  jDayNo %= 12053;

  jYear += 4 * (jDayNo ~/ 1461);

  jDayNo %= 1461;

  if (jDayNo >= 366) {
    jYear += (jDayNo - 1) ~/ 365;
    jDayNo = (jDayNo - 1) % 365;
  }

  int jMonth = 1;

  while (
      jMonth <= 11 &&
      jDayNo >= jDaysInMonth[jMonth]) {
    jDayNo -= jDaysInMonth[jMonth];
    jMonth++;
  }

  final jDay = jDayNo + 1;

  return '$jYear/${jMonth.toString().padLeft(2, '0')}/${jDay.toString().padLeft(2, '0')}';
}

// =====================================================
// صفحه ثبت بازرسی
// =====================================================

class AddInspectionPage
    extends StatefulWidget {
  const AddInspectionPage({
    super.key,
  });

  @override
  State<AddInspectionPage> createState() =>
      _AddInspectionPageState();
}

class _AddInspectionPageState
    extends State<AddInspectionPage> {
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

  bool saving = false;
  bool recording = false;

  List<EvidenceFile> evidences = [];

  @override
  void initState() {
    super.initState();

    dateController.text =
        gregorianToJalali(DateTime.now());
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

  Future<void> save() async {
    if (saving) return;

    final agentCode =
        agentCodeController.text.trim();

    if (agentCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لطفاً کد عامل را وارد کنید.',
          ),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final inspection = Inspection(
        id: DateTime.now()
            .microsecondsSinceEpoch
            .toString(),
        date: dateController.text.trim(),
        agentCode: agentCode,
        agentName:
            agentNameController.text.trim(),
        city:
            cityController.text.trim(),
        problems:
            problemsController.text.trim(),
        evidences:
            List<EvidenceFile>.from(evidences),
      );

      await AppStorage.addInspection(
        inspection,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'بازرسی با موفقیت ثبت شد.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ذخیره بازرسی انجام نشد.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> pickGalleryImages() async {
    // در بخش بعدی تکمیل می‌شود.
  }

  Future<void> takePhoto() async {
    // در بخش بعدی تکمیل می‌شود.
  }

  Future<void> startRecording() async {
    // در بخش بعدی تکمیل می‌شود.
  }

  Future<void> stopRecording() async {
    // در بخش بعدی تکمیل می‌شود.
  }

  Future<void> pickFile() async {
    // در بخش بعدی تکمیل می‌شود.
  }

  void removeEvidence(int index) {
    if (index < 0 ||
        index >= evidences.length) {
      return;
    }

    setState(() {
      evidences.removeAt(index);
    });
  }

  Widget evidenceSection() {
    return Card(
      color: const Color(0xFF101B2E),
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
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
                    icon: const Icon(
                      Icons.photo,
                    ),
                    label:
                        const Text('گالری'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed: takePhoto,
                    icon: const Icon(
                      Icons.camera_alt,
                    ),
                    label:
                        const Text('دوربین'),
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
                    onPressed: recording
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
                    onPressed: pickFile,
                    icon: const Icon(
                      Icons.insert_drive_file,
                    ),
                    label:
                        const Text('فایل'),
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
                style: TextStyle(
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
                    contentPadding:
                        EdgeInsets.zero,
                    leading: Icon(
                      icon,
                      color: const Color(
                        0xFFC9A227,
                      ),
                    ),
                    title: Text(
                      evidence.name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                    trailing:
                        IconButton(
                      icon: const Icon(
                        Icons
                            .delete_outline,
                        color: Colors
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
  }// =====================================================
// ادامه صفحه ثبت بازرسی
// =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ثبت بازرسی جدید',
        ),
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
// فیلد عمومی
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
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
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
  List<Inspection> inspections = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data =
          await AppStorage.getInspections();

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

  String getMonth(String date) {
    final parts = date.trim().split('/');

    if (parts.length < 2) {
      return '';
    }

    final year =
        normalizeDigits(parts[0]);

    final month = normalizeDigits(
      parts[1],
    ).padLeft(2, '0');

    if (year.isEmpty ||
        month.isEmpty) {
      return '';
    }

    return '$year/$month';
  }

  int monthSortKey(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year =
        int.tryParse(parts[0]) ?? 0;

    final monthNumber =
        int.tryParse(parts[1]) ?? 0;

    return (year * 100) + monthNumber;
  }

  String monthTitle(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return month;
    }

    final year = parts[0];

    final monthNumber =
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

    if (monthNumber >= 1 &&
        monthNumber <= 12) {
      return '${names[monthNumber]} $year';
    }

    return month;
  }

  List<String> get months {
    final result = inspections
        .map(
          (item) => getMonth(item.date),
        )
        .where(
          (month) => month.isNotEmpty,
        )
        .toSet()
        .toList();

    result.sort(
      (a, b) => monthSortKey(b)
          .compareTo(monthSortKey(a)),
    );

    return result;
  }

  int countForMonth(String month) {
    return inspections.where(
      (item) =>
          getMonth(item.date) == month,
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بایگانی'),
        actions: [
          IconButton(
            tooltip:
                'بازرسی‌های تکراری',
            icon: const Icon(
              Icons.repeat,
            ),
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
            icon: const Icon(
              Icons.search,
            ),
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
          : months.isEmpty
              ? const Center(
                  child: Text(
                    'هنوز هیچ بازرسی ثبت نشده است',
                    style: TextStyle(
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
                      months.length,
                  itemBuilder:
                      (context, index) {
                    final month =
                        months[index];

                    final count =
                        countForMonth(
                      month,
                    );

                    return Card(
                      child: ListTile(
                        leading:
                            const Icon(
                          Icons.folder,
                          color: Color(
                            0xFFC9A227,
                          ),
                          size: 32,
                        ),
                        title: Text(
                          monthTitle(
                            month,
                          ),
                          style:
                              const TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        subtitle: Text(
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
                                  MonthArchivePage(
                                month: month,
                                monthTitleText:
                                    monthTitle(
                                  month,
                                ),
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
// بایگانی یک ماه
// =====================================================

class MonthArchivePage
    extends StatelessWidget {
  final String month;
  final String monthTitleText;
  final List<Inspection> inspections;

  const MonthArchivePage({
    super.key,
    required this.month,
    required this.monthTitleText,
    required this.inspections,
  });

  String getMonth(String date) {
    final parts = date.trim().split('/');

    if (parts.length < 2) {
      return '';
    }

    return '${normalizeDigits(parts[0])}/${normalizeDigits(parts[1]).padLeft(2, '0')}';
  }

  String getDay(String date) {
    final parts = date.trim().split('/');

    if (parts.length < 3) {
      return date;
    }

    return normalizeDigits(
      parts[2],
    ).padLeft(2, '0');
  }

  int daySortKey(String date) {
    final normalized =
        normalizeDigits(date);

    final parts =
        normalized.split('/');

    if (parts.length < 3) {
      return 0;
    }

    final year =
        int.tryParse(parts[0]) ?? 0;

    final monthNumber =
        int.tryParse(parts[1]) ?? 0;

    final day =
        int.tryParse(parts[2]) ?? 0;

    return (year * 10000) +
        (monthNumber * 100) +
        day;
  }

  List<String> get dates {
    final result = inspections
        .where(
          (item) =>
              getMonth(item.date) ==
              month,
        )
        .map(
          (item) => item.date,
        )
        .where(
          (date) => date.isNotEmpty,
        )
        .toSet()
        .toList();

    result.sort(
      (a, b) => daySortKey(b)
          .compareTo(daySortKey(a)),
    );

    return result;
  }

  int countForDate(String date) {
    return inspections.where(
      (item) => item.date == date,
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          monthTitleText,
        ),
      ),
      body: dates.isEmpty
          ? const Center(
              child: Text(
                'در این ماه بازرسی‌ای ثبت نشده است',
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
                    countForDate(
                  date,
                );

                return Card(
                  child: ListTile(
                    leading:
                        const Icon(
                      Icons
                          .calendar_month,
                      color: Color(
                        0xFFC9A227,
                      ),
                      size: 30,
                    ),
                    title: Text(
                      'روز ${getDay(date)}',
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                    subtitle: Text(
                      '$date  •  $count بازرسی',
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
}// =====================================================
// نمایش مستندات
// =====================================================

class EvidenceViewer extends StatelessWidget {
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
          padding: const EdgeInsets.all(18),
          child: Column(
            children: const [
              Icon(
                Icons.attach_file,
                size: 45,
                color: Colors.white38,
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
      color: const Color(0xFF101B2E),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.folder_special,
                  color: Color(0xFFC9A227),
                ),
                SizedBox(width: 8),
                Text(
                  'مستندات ثبت‌شده',
                  style: TextStyle(
                    color: Color(0xFFC9A227),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...evidences.map(
              (evidence) => EvidenceTile(
                evidence: evidence,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// باز کردن مستند
// =====================================================

Future<void> openEvidence(
  BuildContext context,
  EvidenceFile evidence,
) async {
  final path = evidence.path.trim();

  if (path.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('مسیر مستند خالی است'),
      ),
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
          content: Text(
            'باز کردن فایل موفق نبود: $message',
          ),
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

// =====================================================
// آیتم مستند
// =====================================================

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
        trailing: const Icon(
          Icons.open_in_new,
        ),
        onTap: () => openEvidence(
          context,
          evidence,
        ),
      ),
    );
  }
}

// =====================================================
// نمایش تصویر کامل
// =====================================================

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
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: FutureBuilder<bool>(
          future: file.exists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
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
// جستجوی بایگانی
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
  final TextEditingController codeController =
      TextEditingController();

  String normalizeDigits(String value) {
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

  List<Inspection> get results {
    final code = normalizeDigits(
      codeController.text.trim(),
    );

    if (code.isEmpty) {
      return [];
    }

    return widget.inspections.where((item) {
      final itemCode = normalizeDigits(
        item.agentCode.trim(),
      );

      return itemCode.contains(code);
    }).toList();
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
        title: const Text(
          'جستجوی بایگانی',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: codeController,
              onChanged: (_) {
                setState(() {});
              },
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
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];

                      return Card(
                        child: ListTile(
                          title: Text(
                            item.agentCode,
                          ),
                          subtitle: Text(
                            '${item.date} - '
                            '${item.city.isEmpty ? 'بدون شهر' : item.city}',
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
// بازرسی‌های تکراری - ماهانه
// =====================================================

class RepeatedInspectionsPage
    extends StatefulWidget {
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

  String getMonth(String date) {
    final parts = date.trim().split('/');

    if (parts.length >= 2) {
      final year = normalizeDigits(parts[0]);
      final month = normalizeDigits(
        parts[1],
      ).padLeft(2, '0');

      return '$year/$month';
    }

    return '';
  }

  String persianMonthName(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return month;
    }

    final m = int.tryParse(
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

    if (m >= 1 && m <= 12) {
      return '${names[m]} ${parts[0]}';
    }

    return month;
  }

  int monthSortKey(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year =
        int.tryParse(normalizeDigits(parts[0])) ?? 0;

    final monthNumber =
        int.tryParse(normalizeDigits(parts[1])) ?? 0;

    return year * 100 + monthNumber;
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

      final code = normalizeDigits(
        item.agentCode.trim(),
      );

      if (code.isEmpty) {
        continue;
      }

      groups.putIfAbsent(
        code,
        () => [],
      );

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

  Widget _buildMonthList(
    BuildContext context,
  ) {
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
  }  Widget _buildCodeList(
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

  int _dateSortKey(String date) {
    final parts = date.trim().split('/');

    if (parts.length < 3) {
      return 0;
    }

    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const english = '0123456789';

    String normalize(String value) {
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

    final year =
        int.tryParse(normalize(parts[0])) ?? 0;
    final monthNumber =
        int.tryParse(normalize(parts[1])) ?? 0;
    final day =
        int.tryParse(normalize(parts[2])) ?? 0;

    return year * 10000 +
        monthNumber * 100 +
        day;
  }

  @override
  Widget build(BuildContext context) {
    final sortedRecords = [...records];

    sortedRecords.sort(
      (a, b) => _dateSortKey(b.date).compareTo(
        _dateSortKey(a.date),
      ),
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

class DailyPerformancePage extends StatelessWidget {
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
// گزارش‌ها
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

    if (parts.length >= 2) {
      final year =
          _normalizeDigits(parts[0]);

      final month =
          _normalizeDigits(parts[1])
              .padLeft(2, '0');

      return '$year/$month';
    }

    return '';
  }

  int _monthSortKey(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year = int.tryParse(
          _normalizeDigits(parts[0]),
        ) ??
        0;

    final monthNumber = int.tryParse(
          _normalizeDigits(parts[1]),
        ) ??
        0;

    return year * 100 + monthNumber;
  }

  String _persianMonthName(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return month;
    }

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

    final number = int.tryParse(
          _normalizeDigits(parts[1]),
        ) ??
        0;

    if (number >= 1 && number <= 12) {
      return '${names[number]} ${parts[0]}';
    }

    return month;
  }

  List<String> get _months {
    final result = inspections
        .map((item) => _getMonth(item.date))
        .where((month) => month.isNotEmpty)
        .toSet()
        .toList();

    result.sort(
      (a, b) => _monthSortKey(b).compareTo(
        _monthSortKey(a),
      ),
    );

    return result;
  }

  List<Inspection> _recordsForDate(
    String date,
  ) {
    return inspections.where(
      (item) =>
          item.date.trim() == date.trim(),
    ).toList();
  }

  List<Inspection> _recordsForMonth(
    String month,
  ) {
    return inspections.where(
      (item) =>
          _getMonth(item.date) == month,
    ).toList();
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
      _repeatedGroups(
    String month,
  ) {
    final Map<String, List<Inspection>>
        groups = {};

    for (final item
        in _recordsForMonth(month)) {
      final code = _normalizeDigits(
        item.agentCode.trim(),
      );

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

    int total = 0;

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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      helpText: 'انتخاب تاریخ گزارش',
      cancelText: 'انصراف',
      confirmText: 'تأیید',
    );

    if (picked == null || !mounted) {
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    const Color(0xFFC9A227),
                borderRadius:
                    BorderRadius.circular(12),
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
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
        _recordsForDate(selectedDate);

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
                const Text('تاریخ گزارش'),
            subtitle:
                Text(selectedDate),
            trailing: const Icon(
              Icons.edit_calendar,
            ),
            onTap: _selectDate,
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
          title: 'تعداد دارای مشکل',
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
          icon: Icons.percent,
        ),
      ],
    );
  }

  Widget _monthlyReport() {
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
          icon: Icons.percent,
        ),
        _statCard(
          title:
              'تعداد بازرسی‌های تکراری',
          value:
              repeated.toString(),
          icon: Icons.repeat,
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
  }// =====================================================
// نمایش مستندات
// =====================================================

class EvidenceViewer extends StatelessWidget {
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
          padding: const EdgeInsets.all(18),
          child: Column(
            children: const [
              Icon(
                Icons.attach_file,
                size: 45,
                color: Colors.white38,
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
      color: const Color(0xFF101B2E),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.folder_special,
                  color: Color(0xFFC9A227),
                ),
                SizedBox(width: 8),
                Text(
                  'مستندات ثبت‌شده',
                  style: TextStyle(
                    color: Color(0xFFC9A227),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            ...evidences.map(
              (evidence) => EvidenceTile(
                evidence: evidence,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// باز کردن مستند
// =====================================================

Future<void> openEvidence(
  BuildContext context,
  EvidenceFile evidence,
) async {
  final path = evidence.path.trim();

  if (path.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('مسیر مستند خالی است'),
      ),
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
          content: Text(
            'باز کردن فایل موفق نبود: $message',
          ),
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

// =====================================================
// آیتم مستند
// =====================================================

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
        trailing: const Icon(
          Icons.open_in_new,
        ),
        onTap: () => openEvidence(
          context,
          evidence,
        ),
      ),
    );
  }
}

// =====================================================
// نمایش تصویر کامل
// =====================================================

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
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: FutureBuilder<bool>(
          future: file.exists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
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
// اطلاعات بازرسی
// =====================================================

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
}// =====================================================
// جستجوی بایگانی
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
  final TextEditingController codeController =
      TextEditingController();

  String normalizeDigits(String value) {
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

  List<Inspection> get results {
    final code = normalizeDigits(
      codeController.text.trim(),
    );

    if (code.isEmpty) {
      return [];
    }

    return widget.inspections.where((item) {
      final itemCode = normalizeDigits(
        item.agentCode.trim(),
      );

      return itemCode.contains(code);
    }).toList();
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
        title: const Text(
          'جستجوی بایگانی',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: codeController,
              onChanged: (_) {
                setState(() {});
              },
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'کد عامل',
                prefixIcon: Icon(
                  Icons.numbers,
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];

                      return Card(
                        child: ListTile(
                          title: Text(
                            item.agentCode,
                          ),
                          subtitle: Text(
                            '${item.date} - ${item.city.isEmpty ? 'بدون شهر' : item.city}',
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
// بازرسی‌های تکراری - ماهانه
// =====================================================

class RepeatedInspectionsPage
    extends StatefulWidget {
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

  // استخراج ماه از تاریخ شمسی
  // مثال:
  // ۱۴۰۵/۰۵/۲۰ -> ۱۴۰۵/۰۵

  String getMonth(String date) {
    final parts = date.trim().split('/');

    if (parts.length >= 2) {
      final year = normalizeDigits(parts[0]);

      final month = normalizeDigits(
        parts[1],
      ).padLeft(2, '0');

      return '$year/$month';
    }

    return date;
  }

  String persianMonthName(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return month;
    }

    final m = int.tryParse(
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

    if (m >= 1 && m <= 12) {
      return '${names[m]} ${parts[0]}';
    }

    return month;
  }

  int monthSortKey(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year =
        int.tryParse(normalizeDigits(parts[0])) ?? 0;

    final monthNumber =
        int.tryParse(normalizeDigits(parts[1])) ?? 0;

    return year * 100 + monthNumber;
  }

  List<String> get months {
    final result = widget.inspections
        .map(
          (item) => getMonth(item.date),
        )
        .where(
          (month) => month.isNotEmpty,
        )
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
    final Map<String, List<Inspection>> groups =
        {};

    for (final item in widget.inspections) {
      if (getMonth(item.date) != month) {
        continue;
      }

      final code = normalizeDigits(
        item.agentCode.trim(),
      );

      if (code.isEmpty) {
        continue;
      }

      groups.putIfAbsent(
        code,
        () => [],
      );

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

  Widget _buildMonthList(
    BuildContext context,
  ) {
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
                style: TextStyle(
                  fontSize: 17,
                ),
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
          icon: const Icon(
            Icons.arrow_back,
          ),
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
                    itemBuilder: (context, index) {
                      final code =
                          groups.keys.elementAt(index);

                      final records =
                          groups[code]!;

                      return Card(
                        child: ListTile(
                          leading: const Icon(
                            Icons.store,
                            color:
                                Color(0xFFC9A227),
                          ),
                          title: Text(
                            code,
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
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

class RepeatedDatesPage
    extends StatelessWidget {
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

  int dateSortKey(String date) {
    final parts = date.trim().split('/');

    if (parts.length < 3) {
      return 0;
    }

    final year =
        int.tryParse(
          normalizeDigits(parts[0]),
        ) ??
        0;

    final month =
        int.tryParse(
          normalizeDigits(parts[1]),
        ) ??
        0;

    final day =
        int.tryParse(
          normalizeDigits(parts[2]),
        ) ??
        0;

    return year * 10000 +
        month * 100 +
        day;
  }

  @override
  Widget build(BuildContext context) {
    final sortedRecords = [...records];

    sortedRecords.sort(
      (a, b) => dateSortKey(a.date).compareTo(
        dateSortKey(b.date),
      ),
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
              final item =
                  sortedRecords[index];

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
                      fontWeight:
                          FontWeight.bold,
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
}// =====================================================
// صفحات گزارش و آمار
// =====================================================

class DailyPerformancePage extends StatelessWidget {
  const DailyPerformancePage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'ثبت عملکرد روزانه',
      message: 'این بخش در مرحله بعد تکمیل می‌شود.',
      icon: Icons.today,
    );
  }
}

// =====================================================
// صفحه گزارش‌ها
// =====================================================

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
  });

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Inspection> inspections = [];
  bool isLoading = true;

  String selectedDate = '';
  String? selectedMonth;

  @override
  void initState() {
    super.initState();

    selectedDate = gregorianToJalali(
      DateTime.now(),
    );

    _loadInspections();
  }

  Future<void> _loadInspections() async {
    try {
      final data = await AppStorage.getInspections();

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

  // ===================================================
  // تبدیل ارقام فارسی و عربی به انگلیسی
  // ===================================================

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

  // ===================================================
  // استخراج ماه
  // ===================================================

  String _getMonth(String date) {
    final parts = date.trim().split('/');

    if (parts.length >= 2) {
      final year = _normalizeDigits(
        parts[0],
      );

      final month = _normalizeDigits(
        parts[1],
      ).padLeft(2, '0');

      return '$year/$month';
    }

    return '';
  }

  // ===================================================
  // شماره ماه
  // ===================================================

  int _monthNumber(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final value = _normalizeDigits(
      parts[1],
    );

    return int.tryParse(value) ?? 0;
  }

  // ===================================================
  // نام فارسی ماه
  // ===================================================

  String _persianMonthName(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return month;
    }

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

    final number = _monthNumber(month);

    if (number >= 1 && number <= 12) {
      return '${names[number]} ${parts[0]}';
    }

    return month;
  }

  // ===================================================
  // لیست ماه‌ها
  // ===================================================

  List<String> get _months {
    final result = inspections
        .map(
          (item) => _getMonth(item.date),
        )
        .where(
          (month) => month.isNotEmpty,
        )
        .toSet()
        .toList();

    result.sort(
      (a, b) => _monthSortKey(b).compareTo(
        _monthSortKey(a),
      ),
    );

    return result;
  }

  int _monthSortKey(String month) {
    final parts = month.split('/');

    if (parts.length != 2) {
      return 0;
    }

    final year = int.tryParse(
          _normalizeDigits(parts[0]),
        ) ??
        0;

    final monthNumber = int.tryParse(
          _normalizeDigits(parts[1]),
        ) ??
        0;

    return year * 100 + monthNumber;
  }

  // ===================================================
  // رکوردهای یک تاریخ
  // ===================================================

  List<Inspection> _recordsForDate(
    String date,
  ) {
    final normalizedDate =
        _normalizeDate(date);

    return inspections.where((item) {
      return _normalizeDate(item.date) ==
          normalizedDate;
    }).toList();
  }

  // ===================================================
  // یکسان‌سازی تاریخ
  // ===================================================

  String _normalizeDate(String date) {
    final parts = date.trim().split('/');

    if (parts.length < 3) {
      return _normalizeDigits(date.trim());
    }

    final year = _normalizeDigits(
      parts[0],
    );

    final month = _normalizeDigits(
      parts[1],
    ).padLeft(2, '0');

    final day = _normalizeDigits(
      parts[2],
    ).padLeft(2, '0');

    return '$year/$month/$day';
  }

  // ===================================================
  // رکوردهای یک ماه
  // ===================================================

  List<Inspection> _recordsForMonth(
    String month,
  ) {
    return inspections.where((item) {
      return _getMonth(item.date) == month;
    }).toList();
  }

  // ===================================================
  // آیا بازرسی مشکل دارد؟
  // ===================================================

  bool _hasProblem(
    Inspection item,
  ) {
    return item.problems.trim().isNotEmpty;
  }

  // ===================================================
  // تعداد مشکلات
  // ===================================================

  int _problemCount(
    List<Inspection> records,
  ) {
    return records.where(_hasProblem).length;
  }

  // ===================================================
  // درصد مشکلات
  // ===================================================

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

  // ===================================================
  // گروه‌بندی بازرسی‌های تکراری
  // ===================================================

  Map<String, List<Inspection>> _repeatedGroups(
    String month,
  ) {
    final Map<String, List<Inspection>> groups =
        {};

    for (final item in _recordsForMonth(month)) {
      final code = _normalizeDigits(
        item.agentCode.trim(),
      );

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

  // ===================================================
  // تعداد کل بازرسی‌های تکراری
  // ===================================================

  int _repeatedInspectionCount(
    String month,
  ) {
    final groups = _repeatedGroups(month);

    var total = 0;

    for (final records in groups.values) {
      total += records.length;
    }

    return total;
  }

  // ===================================================
  // گروه‌بندی بر اساس شهر
  // ===================================================

  Map<String, List<Inspection>> _cityGroups(
    List<Inspection> records,
  ) {
    final Map<String, List<Inspection>> groups =
        {};

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

  // ===================================================
  // انتخاب تاریخ گزارش
  // ===================================================

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      helpText: 'انتخاب تاریخ گزارش',
      cancelText: 'انصراف',
      confirmText: 'تأیید',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      selectedDate = gregorianToJalali(
        picked,
      );
    });
  }

  // ===================================================
  // کارت آماری
  // ===================================================

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final card = Card(
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
                borderRadius:
                    BorderRadius.circular(12),
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFC9A227),
                fontSize: 23,
                fontWeight: FontWeight.bold,
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: card,
    );
  }

  // ===================================================
  // گزارش روزانه
  // ===================================================

  Widget _dailyReport() {
    final records =
        _recordsForDate(selectedDate);

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
            color: Color(0xFFC9A227),
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        Card(
          color: const Color(0xFF101B2E),
          child: ListTile(
            leading: const Icon(
              Icons.calendar_month,
              color: Color(0xFFC9A227),
            ),
            title: const Text(
              'تاریخ گزارش',
            ),
            subtitle: Text(
              selectedDate,
            ),
            trailing: const Icon(
              Icons.edit_calendar,
            ),
            onTap: _selectDate,
          ),
        ),

        _statCard(
          title: 'تعداد بازرسی انجام‌شده',
          value: records.length.toString(),
          icon: Icons.assignment_turned_in,
        ),

        _statCard(
          title: 'تعداد دارای مشکل',
          value: problems.toString(),
          icon: Icons.warning_amber_rounded,
        ),

        _statCard(
          title: 'تعداد بدون مشکل',
          value: withoutProblems.toString(),
          icon: Icons.check_circle_outline,
        ),

        _statCard(
          title: 'درصد دارای مشکل',
          value:
              '${percent.toStringAsFixed(1)}٪',
          icon: Icons.percent,
        ),
      ],
    );
  }

  // ===================================================
  // گزارش ماهانه
  // ===================================================

  Widget _monthlyReport() {
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
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: month,
                isExpanded: true,
                dropdownColor:
                    const Color(0xFF101B2E),
                items: months.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      _persianMonthName(item),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    selectedMonth = value;
                  });
                },
              ),
            ),
          ),
        ),

        _statCard(
          title: 'کل بازرسی‌های ماه',
          value: records.length.toString(),
          icon: Icons.assignment_turned_in,
        ),

        _statCard(
          title: 'کل مشکلات ماه',
          value: problems.toString(),
          icon: Icons.warning_amber_rounded,
        ),

        _statCard(
          title: 'بازرسی‌های بدون مشکل',
          value: withoutProblems.toString(),
          icon: Icons.check_circle_outline,
        ),

        _statCard(
          title: 'درصد مشکلات',
          value:
              '${percent.toStringAsFixed(1)}٪',
          icon: Icons.percent,
        ),

        _statCard(
          title: 'تعداد بازرسی‌های تکراری',
          value: repeated.toString(),
          icon: Icons.repeat,
          onTap: repeated == 0
              ? null
              : () {
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

        if (repeatedGroups.isNotEmpty) ...[
          const SizedBox(height: 8),

          Card(
            color: const Color(0xFF101B2E),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '${repeatedGroups.length} کد عامل در این ماه حداقل ۲ بار بازرسی شده‌اند.',
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }// =====================================================
// ادامه: تنظیمات
// =====================================================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController inspectorController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    inspectorController.text = 'رضا طاحونی';
  }

  @override
  void dispose() {
    inspectorController.dispose();
    super.dispose();
  }

  void saveSettings() {
    final name = inspectorController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نام بازرس را وارد کنید'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تنظیمات با موفقیت ذخیره شد'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF101B2E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Color(0xFFC9A227),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'اطلاعات بازرس',
                        style: TextStyle(
                          color: Color(0xFFC9A227),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: inspectorController,
                    decoration: const InputDecoration(
                      labelText: 'نام بازرس',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        'ذخیره تنظیمات',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.lock,
                color: Color(0xFFC9A227),
              ),
              title: const Text('رمز عبور'),
              subtitle: const Text(
                'تنظیم رمز عبور برنامه',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'بخش رمز عبور در مرحله بعد تکمیل می‌شود.',
                    ),
                  ),
                );
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.calendar_month,
                color: Color(0xFFC9A227),
              ),
              title: const Text('تاریخ و زمان'),
              subtitle: const Text(
                'تنظیمات تاریخ و زمان برنامه',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تاریخ و زمان برنامه از تنظیمات دستگاه استفاده می‌کند.',
                    ),
                  ),
                );
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(
                Icons.info_outline,
                color: Color(0xFFC9A227),
              ),
              title: const Text('درباره برنامه'),
              subtitle: const Text(
                'سامانه مدیریت بازرسی',
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'سامانه مدیریت بازرسی',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(
                    Icons.shield,
                    color: Color(0xFFC9A227),
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
}
