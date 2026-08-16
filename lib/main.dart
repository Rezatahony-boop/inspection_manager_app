import 'package:flutter/material.dart';

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
      ),
      home: const LoginPage(),
    );
  }
}

// ================= LOGIN =================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController passwordController = TextEditingController();

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user,
                size: 80,
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
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'رمز عبور',
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
                    'ورود',
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

// ================= DASHBOARD =================

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('داشبورد'),
        centerTitle: true,
        backgroundColor: const Color(0xFF08111F),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        children: [
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
            title: 'ثبت بازرسی جدید',
            icon: Icons.assignment,
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
              size: 48,
              color: const Color(0xFFC9A227),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= DAILY PERFORMANCE =================

class DailyPerformancePage extends StatelessWidget {
  const DailyPerformancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'ثبت عملکرد روزانه',
      message: 'در این بخش عملکرد روزانه بازرس ثبت خواهد شد.',
      icon: Icons.today,
    );
  }
}

// ================= NEW INSPECTION =================

class NewInspectionPage extends StatelessWidget {
  const NewInspectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'ثبت بازرسی جدید',
      message: 'در این بخش اطلاعات بازرسی جدید ثبت خواهد شد.',
      icon: Icons.assignment,
    );
  }
}

// ================= ARCHIVE =================

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'بایگانی',
      message: 'سوابق بازرسی‌ها در این بخش نمایش داده خواهد شد.',
      icon: Icons.folder,
    );
  }
}

// ================= REPORTS =================

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'گزارش‌ها',
      message: 'آمار روزانه، ماهانه و شهری در این بخش قرار می‌گیرد.',
      icon: Icons.bar_chart,
    );
  }
}

// ================= SETTINGS =================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimplePage(
      title: 'تنظیمات',
      message: 'تنظیمات بازرس، رمز عبور و اطلاعات برنامه در این بخش قرار می‌گیرد.',
      icon: Icons.settings,
    );
  }
}

// ================= SIMPLE PAGE =================

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
        centerTitle: true,
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
              const SizedBox(height: 25),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC9A227),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
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
