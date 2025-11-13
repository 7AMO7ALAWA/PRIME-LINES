import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart'; // ✅ للـ Clipboard
import 'package:url_launcher/url_launcher.dart'; // ✅ للاتصال

// ===================================================
// 🔔 Background Handler
// ===================================================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

// ===================================================
// ⚙️ Config from Vercel
// ===================================================
class Config {
  final String supabaseUrl;
  final String supabaseKey;
  final String adminPass;

  Config({
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.adminPass,
  });

  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      supabaseUrl: json['supabase_url'],
      supabaseKey: json['supabase_key'],
      adminPass: json['admin_pass'],
    );
  }
}

Future<Config?> fetchConfig() async {
  try {
    final url = Uri.parse('https://mohamed-hany-project.vercel.app/api/config');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return Config.fromJson(jsonDecode(response.body));
    }
  } catch (e) {
    print('Error fetching config: $e');
  }
  return null;
}

// ===================================================
// 🚀 Main
// ===================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await fetchConfig();
  if (config == null) {
    throw Exception("Failed to fetch configuration from server");
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseKey,
  );

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp(adminPass: config.adminPass));
}

// ===================================================
// 🏠 MyApp
// ===================================================
class MyApp extends StatelessWidget {
  final String adminPass;
  const MyApp({super.key, required this.adminPass});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '📘 تسجيل الطلاب',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.indigo.shade50,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.indigo, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: RegisterScreen(adminPass: adminPass),
    );
  }
}

// ===================================================
// 📝 RegisterScreen
// ===================================================
class RegisterScreen extends StatefulWidget {
  final String adminPass;
  const RegisterScreen({super.key, required this.adminPass});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();

  String? _selectedLevel;
  String? _selectedDept;
  String? _selectedTripType;
  bool loading = false;
  bool hasInternet = true;

  final supabase = Supabase.instance.client;
  String? _deviceId;

  final List<String> baseLevels = [
    "📖 الفرقة الأولى",
    "📘 الفرقة الثانية",
    "📙 الفرقة الثالثة",
    "📗 الفرقة الرابعة",
  ];
  final String extraLevel = "📕 اعدادي";

  final List<String> departments = [
    "💻 علوم الحاسب",
    "🗂 نظم المعلومات",
    "🌐 اداره اعمال",
    "📊 هندسه",
  ];

  final List<String> tripTypes = [
    "🚍 ذهاب وعودة",
    "➡️ ذهاب فقط",
    "⬅️ عودة فقط",
  ];

  // -----------------------------------------------
  // 🧩 Local Storage
  // -----------------------------------------------
  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedId = prefs.getString("device_id");
    if (savedId == null) {
      savedId = const Uuid().v4();
      await prefs.setString("device_id", savedId);
    }
    setState(() {
      _deviceId = savedId;
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    _name.text = prefs.getString('name') ?? '';
    _phone.text = prefs.getString('phone') ?? '';
    _notes.text = prefs.getString('notes') ?? '';
    setState(() {
      _selectedLevel = prefs.getString('level');
      _selectedDept = prefs.getString('department');
      _selectedTripType = prefs.getString('trip_type');
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _name.text.trim());
    await prefs.setString('phone', _phone.text.trim());
    await prefs.setString('notes', _notes.text.trim());
    if (_selectedLevel != null) await prefs.setString('level', _selectedLevel!);
    if (_selectedDept != null) await prefs.setString('department', _selectedDept!);
    if (_selectedTripType != null) await prefs.setString('trip_type', _selectedTripType!);
  }

  // -----------------------------------------------
  // 🌐 Internet Check
  // -----------------------------------------------
  Future<void> _checkInternet() async {
    var result = await Connectivity().checkConnectivity();
    setState(() {
      hasInternet = result != ConnectivityResult.none;
    });
    if (!hasInternet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ لا يوجد إنترنت"), backgroundColor: Colors.red),
      );
    }
  }

  // -----------------------------------------------
  // 📤 Register Student
  // -----------------------------------------------
  Future<void> registerStudent() async {
    String name = _name.text.trim();
    String phone = _phone.text.trim();
    String notes = _notes.text.trim();

    if (name.isEmpty ||
        phone.isEmpty ||
        _selectedLevel == null ||
        _selectedDept == null ||
        _selectedTripType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ من فضلك املأ كل الحقول"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final phoneRegex = RegExp(r'^\d{11}$');
    if (!phoneRegex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ رقم الهاتف يجب أن يكون 11 أرقام فقط"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => loading = true);
    await _checkInternet();
    if (!hasInternet) {
      setState(() => loading = false);
      return;
    }

    try {
      await supabase.from('students').insert({
        'name': name,
        'phone': phone,
        'device_id': _deviceId,
        'level': _selectedLevel,
        'department': _selectedDept,
        'trip_type': _selectedTripType,
        'notes': notes,
      });

      await _saveData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم التسجيل بنجاح 🎉'),
          backgroundColor: Colors.green,
        ),
      );

      _name.clear();
      _phone.clear();
      _notes.clear();
      setState(() {
        _selectedLevel = null;
        _selectedDept = null;
        _selectedTripType = null;
      });
    } catch (e) {
      String message = "حدث خطأ غير متوقع";
      if (e is PostgrestException) message = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    _loadSavedData();

    FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.notification?.title}');
    });

    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        hasInternet = result != ConnectivityResult.none;
      });
      if (!hasInternet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ لا يوجد إنترنت"), backgroundColor: Colors.red),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📘 تسجيل الطلاب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminLoginScreen(adminPass: widget.adminPass),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 8,
            shadowColor: Colors.indigo.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "👨‍🎓 بيانات الطالب",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: '👤 الاسم')),
                  const SizedBox(height: 15),
                  TextField(controller: _phone, decoration: const InputDecoration(labelText: '📱 رقم الموبايل')),
                  const SizedBox(height: 15),

                  // القسم
                  DropdownButtonFormField<String>(
                    value: _selectedDept,
                    decoration: const InputDecoration(labelText: "🏫 القسم"),
                    items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) => setState(() {
                      _selectedDept = val;
                      if (_selectedLevel == extraLevel && _selectedDept != "📊 هندسه") {
                        _selectedLevel = null;
                      }
                    }),
                  ),
                  const SizedBox(height: 15),

                  // الفرقة
                  DropdownButtonFormField<String>(
                    value: _selectedLevel,
                    decoration: const InputDecoration(labelText: "📖 الفرقة"),
                    items: (_selectedDept == "📊 هندسه"
                            ? [extraLevel, ...baseLevels]
                            : baseLevels)
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedLevel = val),
                  ),
                  const SizedBox(height: 15),

                  // نوع الحجز
                  DropdownButtonFormField<String>(
                    value: _selectedTripType,
                    decoration: const InputDecoration(labelText: "🚌 نوع الحجز"),
                    items: tripTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() => _selectedTripType = val),
                  ),
                  const SizedBox(height: 15),

                  // الملاحظات
                  TextField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: '📝 الملاحظات'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 25),

                  // زر التسجيل
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    onPressed: loading ? null : registerStudent,
                    icon: const Icon(Icons.check_circle_outline),
                    label: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('تسجيل', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================
// 🔐 AdminLoginScreen
// ===================================================
class AdminLoginScreen extends StatefulWidget {
  final String adminPass;
  const AdminLoginScreen({super.key, required this.adminPass});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _password = TextEditingController();

  void checkPassword() {
    if (_password.text.trim() == widget.adminPass) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StudentListScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚫 كلمة المرور غير صحيحة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🔐 تسجيل الدخول")),
      body: Center(
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("🔑 أدخل كلمة المرور", style: TextStyle(fontSize: 18)),
                const SizedBox(height: 15),
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: "كلمة المرور")),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: checkPassword, child: const Text("دخول")),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================
// 📋 StudentListScreen
// ===================================================
class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> students = [];

  Future<void> fetchStudents() async {
    try {
      final data = await supabase.from('students').select().order('id', ascending: false);
      setState(() {
        students = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {
      setState(() {
        students = [];
      });
    }
  }

  Future<void> deleteStudent(int id) async {
    try {
      await supabase.from('students').delete().eq('id', id);
      setState(() {
        students.removeWhere((s) => s['id'] == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ تم حذف الطالب بنجاح"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ فشل حذف الطالب"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    fetchStudents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📋 قائمة الطلاب"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchStudents),
        ],
      ),
      body: students.isEmpty
          ? const Center(child: Text("😢 لا يوجد طلاب"))
          : ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final s = students[index];
                final dateTime = DateTime.tryParse(s['created_at'] ?? '');
                final formattedDate = dateTime != null
                    ? DateFormat('dd/MM/yyyy - hh:mm a').format(dateTime)
                    : '';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text("👤 ${s['name'] ?? ''}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text("📱 ${s['phone'] ?? ''}")),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20, color: Colors.indigo),
                              tooltip: 'نسخ الرقم',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: s['phone'] ?? ''));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("✅ تم نسخ رقم الهاتف"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.call, size: 20, color: Colors.green),
                              tooltip: 'اتصال',
                              onPressed: () async {
                                final phone = s['phone'] ?? '';
                                if (phone.isNotEmpty) {
                                  final Uri url = Uri(scheme: 'tel', path: phone);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("❌ لا يمكن فتح الاتصال")),
                                    );
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 22, color: Colors.red),
                              tooltip: 'حذف الطالب',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("تأكيد الحذف"),
                                    content: Text("هل أنت متأكد أنك تريد حذف ${s['name']}؟"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text("إلغاء"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        child: const Text("حذف"),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) await deleteStudent(s['id']);
                              },
                            ),
                          ],
                        ),
                        Text("🚌 ${s['trip_type'] ?? ''}"),
                        Text("⏰ $formattedDate"),
                        Text("📝 ${s['notes'] ?? 'لا توجد ملاحظات'}"),
                      ],
                    ),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(s['level'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(s['department'] ?? '', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ===================================================
// ℹ️ AboutScreen
// ===================================================
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ℹ️ حول التطبيق")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(radius: 70, backgroundImage: AssetImage("assets/images/7AMO.jpg")),
            SizedBox(height: 25),
            Text(
              "👨‍💻 MOHAMED HANY HALAWA",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            SizedBox(height: 10),
            Text("📞 Phone: 01096365804", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text("🔗 Instagram: www.instagram.com/eng_mohamed_halawa", style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
