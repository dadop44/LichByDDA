import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vnlunar/vnlunar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

// ==========================================
// 1. DATA MODELS & UTILS
// ==========================================

class TodoTask {
  String id;
  String title;
  bool isDone;
  DateTime date;

  TodoTask(
      {required this.id,
      required this.title,
      this.isDone = false,
      required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone,
      'date': date.toIso8601String()
    };
  }

  factory TodoTask.fromMap(Map<String, dynamic> map) {
    return TodoTask(
        id: map['id'],
        title: map['title'],
        isDone: map['isDone'],
        date: DateTime.parse(map['date']));
  }
}

class LunarDateModel {
  final int day;
  final int month;
  final int year;
  final bool isLeap;
  final String canChiDay;
  final String canChiMonth;
  final String canChiYear;
  final bool isHoliday;
  final String holidayName;
  final String tietKhi;
  final String gioCanChi;

  LunarDateModel({
    required this.day,
    required this.month,
    required this.year,
    required this.isLeap,
    required this.canChiDay,
    required this.canChiMonth,
    required this.canChiYear,
    this.isHoliday = false,
    this.holidayName = "",
    this.tietKhi = "",
    this.gioCanChi = "",
  });
}

class LunarUtils {
  static final List<String> CAN = [
    "Giáp",
    "Ất",
    "Bính",
    "Đinh",
    "Mậu",
    "Kỷ",
    "Canh",
    "Tân",
    "Nhâm",
    "Quý"
  ];
  static final List<String> CHI = [
    "Tý",
    "Sửu",
    "Dần",
    "Mão",
    "Thìn",
    "Tỵ",
    "Ngọ",
    "Mùi",
    "Thân",
    "Dậu",
    "Tuất",
    "Hợi"
  ];

  static final List<Map<String, String>> TRUC_DATA = [
    {"tot": "Cúng tế, cầu phúc", "xau": "Chữa bệnh, động thổ"},
    {"tot": "Giao dịch, nạp tài", "xau": "Kiện tụng, đi xa"},
    {"tot": "Họp mặt, xuất hành", "xau": "An táng, đào giếng"},
    {"tot": "Xây dựng, cưới hỏi", "xau": "Thưa kiện, tranh chấp"},
    {"tot": "Khai trương, cầu tài", "xau": "Chôn cất, tu sửa"},
    {"tot": "Mọi việc hanh thông", "xau": "Đi sông nước"},
    {"tot": "Thẩm mỹ, chữa bệnh", "xau": "Cưới hỏi, xây nhà"},
    {"tot": "Nghỉ ngơi, an dưỡng", "xau": "Khởi công việc lớn"},
    {"tot": "Nhập học, kết hôn", "xau": "Kiện tụng, tranh cãi"},
    {"tot": "Tế tự, cầu an", "xau": "Động thổ, phá dỡ"},
    {"tot": "Xuất hành, cưới hỏi", "xau": "Kiện tụng"},
    {"tot": "An táng, cúng lễ", "xau": "Nhậm chức, khai trương"},
  ];

  static final List<Map<String, dynamic>> HOLIDAYS_DATA = [
    {
      "name": "Tết Dương Lịch",
      "day": 1,
      "month": 1,
      "type": "solar",
      "desc": "Ngày đầu tiên của năm mới theo lịch Gregor."
    },
    {
      "name": "Mùng 1 Tết Nguyên Đán",
      "day": 1,
      "month": 1,
      "type": "lunar",
      "desc": "Tết cổ truyền lớn nhất của dân tộc Việt Nam."
    },
    {
      "name": "Mùng 2 Tết Nguyên Đán",
      "day": 2,
      "month": 1,
      "type": "lunar",
      "desc": "Tết cổ truyền lớn nhất của dân tộc Việt Nam."
    },
    {
      "name": "Mùng 3 Tết Nguyên Đán",
      "day": 3,
      "month": 1,
      "type": "lunar",
      "desc": "Tết cổ truyền lớn nhất của dân tộc Việt Nam."
    },
    {
      "name": "Mùng 4 Tết Nguyên Đán",
      "day": 4,
      "month": 1,
      "type": "lunar",
      "desc": "Tết cổ truyền lớn nhất của dân tộc Việt Nam."
    },
    {
      "name": "Mùng 5 Tết Nguyên Đán",
      "day": 5,
      "month": 1,
      "type": "lunar",
      "desc": "Tết cổ truyền lớn nhất của dân tộc Việt Nam."
    },
    {
      "name": "Giỗ Tổ Hùng Vương",
      "day": 10,
      "month": 3,
      "type": "lunar",
      "desc": "Ngày tưởng nhớ công ơn các Vua Hùng đã có công dựng nước."
    },
    {
      "name": "Giải phóng Miền Nam",
      "day": 30,
      "month": 4,
      "type": "solar",
      "desc": "Kỷ niệm ngày giải phóng hoàn toàn miền Nam, thống nhất đất nước."
    },
    {
      "name": "Quốc tế Lao Động",
      "day": 1,
      "month": 5,
      "type": "solar",
      "desc": "Ngày hội của giai cấp công nhân và nhân dân lao động."
    },
    {
      "name": "Phật Đản",
      "day": 15,
      "month": 4,
      "type": "lunar",
      "desc": "Kỷ niệm ngày sinh của Đức Phật Thích Ca Mâu Ni."
    },
    {
      "name": "Tết Đoan Ngọ",
      "day": 5,
      "month": 5,
      "type": "lunar",
      "desc": "Tết diệt sâu bọ, cầu mong mùa màng bội thu, sức khỏe dồi dào."
    },
    {
      "name": "Lễ Vu Lan",
      "day": 15,
      "month": 7,
      "type": "lunar",
      "desc": "Ngày báo hiếu cha mẹ và xá tội vong nhân."
    },
    {
      "name": "Quốc Khánh",
      "day": 2,
      "month": 9,
      "type": "solar",
      "desc": "Kỷ niệm ngày Chủ tịch Hồ Chí Minh đọc Tuyên ngôn Độc lập."
    },
    {
      "name": "Tết Trung Thu",
      "day": 15,
      "month": 8,
      "type": "lunar",
      "desc": "Tết đoàn viên, tết thiếu nhi với tục rước đèn, phá cỗ."
    },
    {
      "name": "Ông Táo về trời",
      "day": 23,
      "month": 12,
      "type": "lunar",
      "desc": "Ngày Táo Quân lên chầu trời báo cáo tình hình hạ giới."
    },
    {
      "name": "Giáng Sinh",
      "day": 24,
      "month": 12,
      "type": "solar",
      "desc": "Lễ kỷ niệm ngày sinh của Chúa Giêsu."
    },
    {
      "name": "QĐND Việt Nam",
      "day": 22,
      "month": 12,
      "type": "solar",
      "desc": "Lễ kỷ niệm ngày thành lập quân đội nhân dân Việt Nam."
    },
    {
      "name": "Valantine",
      "day": 14,
      "month": 2,
      "type": "solar",
      "desc": "Ngày lễ tình nhân."
    },
    {
      "name": "Tết thiếu nhi",
      "day": 1,
      "month": 6,
      "type": "solar",
      "desc": "Ngày quốc tế thiếu nhi."
    },
    {
      "name": "Quốc tế phụ nữ",
      "day": 8,
      "month": 3,
      "type": "solar",
      "desc": "Ngày quốc tế Phụ Nữ."
    },
    {
      "name": "Phụ nữ Việt Nam",
      "day": 20,
      "month": 10,
      "type": "solar",
      "desc": "Ngày Phụ Nữ Việt Nam."
    },
    {
      "name": "Thương binh, liệt sĩ Việt Nam",
      "day": 27,
      "month": 7,
      "type": "solar",
      "desc": "Ngày thương binh, liệt sĩ Việt Nam."
    },
  ];

  static Map<String, dynamic> checkHoliday(
      int solarDay, int solarMonth, int lunarDay, int lunarMonth) {
    for (var h in HOLIDAYS_DATA) {
      if (h['type'] == 'solar' &&
          h['day'] == solarDay &&
          h['month'] == solarMonth)
        return {"isHoliday": true, "name": h['name']};
      if (h['type'] == 'lunar' &&
          h['day'] == lunarDay &&
          h['month'] == lunarMonth)
        return {"isHoliday": true, "name": h['name']};
    }
    return {"isHoliday": false, "name": ""};
  }

  static String getSolarTerm(DateTime date) {
    int day = date.day;
    int month = date.month;
    if (month == 1)
      return day < 6 ? "Tiểu Hàn" : (day < 21 ? "Tiểu Hàn" : "Đại Hàn");
    if (month == 2)
      return day < 4 ? "Đại Hàn" : (day < 19 ? "Lập Xuân" : "Vũ Thủy");
    if (month == 3)
      return day < 6 ? "Vũ Thủy" : (day < 21 ? "Kinh Trập" : "Xuân Phân");
    if (month == 4)
      return day < 5 ? "Xuân Phân" : (day < 20 ? "Thanh Minh" : "Cốc Vũ");
    if (month == 5)
      return day < 6 ? "Cốc Vũ" : (day < 21 ? "Lập Hạ" : "Tiểu Mãn");
    if (month == 6)
      return day < 6 ? "Tiểu Mãn" : (day < 21 ? "Mang Chủng" : "Hạ Chí");
    if (month == 7)
      return day < 7 ? "Hạ Chí" : (day < 23 ? "Tiểu Thử" : "Đại Thử");
    if (month == 8)
      return day < 8 ? "Đại Thử" : (day < 23 ? "Lập Thu" : "Xử Thử");
    if (month == 9)
      return day < 8 ? "Xử Thử" : (day < 23 ? "Bạch Lộ" : "Thu Phân");
    if (month == 10)
      return day < 8 ? "Thu Phân" : (day < 23 ? "Hàn Lộ" : "Sương Giáng");
    if (month == 11)
      return day < 7 ? "Sương Giáng" : (day < 22 ? "Lập Đông" : "Tiểu Tuyết");
    if (month == 12)
      return day < 7 ? "Tiểu Tuyết" : (day < 22 ? "Đại Tuyết" : "Đông Chí");
    return "";
  }

  static String getCanChiHour(String canDay, int hour) {
    int chiIndex =
        (hour == 23 || hour == 0) ? 0 : ((hour < 23) ? (hour + 1) ~/ 2 : 0);
    int canDayIndex = CAN.indexOf(canDay.split(" ")[0]);
    int currentCanIndex = ((canDayIndex % 5) * 2 + chiIndex) % 10;
    return "${CAN[currentCanIndex]} ${CHI[chiIndex]}";
  }

  static LunarDateModel convertSolarToLunar(DateTime date) {
    List<int> lunarValues =
        convertSolar2Lunar(date.day, date.month, date.year, 7);
    int day = lunarValues[0];
    int month = lunarValues[1];
    int year = lunarValues[2];
    bool isLeap = lunarValues[3] == 1;
    var holidayInfo = checkHoliday(date.day, date.month, day, month);

    int jd = date.day +
        ((153 * (date.month + 12 * ((14 - date.month) ~/ 12) - 3) + 2) ~/ 5) +
        365 * (date.year + 4800 - ((14 - date.month) ~/ 12)) +
        ((date.year + 4800 - ((14 - date.month) ~/ 12)) ~/ 4) -
        ((date.year + 4800 - ((14 - date.month) ~/ 12)) ~/ 100) +
        ((date.year + 4800 - ((14 - date.month) ~/ 12)) ~/ 400) -
        32045;
    String canDayRaw = CAN[(jd + 9) % 10];
    String canDay = CAN[(jd + 9) % 10];
    String chiDay = CHI[(jd + 1) % 12];
    String canMonth = CAN[(year * 12 + month + 3) % 10];
    String chiMonth = CHI[(month + 1) % 12];
    String canYear = CAN[(year + 6) % 10];
    String chiYear = CHI[(year + 8) % 12];

    DateTime now = DateTime.now();
    int currentHour = (date.year == now.year &&
            date.month == now.month &&
            date.day == now.day)
        ? now.hour
        : 12;
    String gioCanChi = getCanChiHour(canDayRaw, currentHour);

    return LunarDateModel(
      day: day,
      month: month,
      year: year,
      isLeap: isLeap,
      canChiDay: "$canDay $chiDay",
      canChiMonth: "$canMonth $chiMonth",
      canChiYear: "$canYear $chiYear",
      isHoliday: holidayInfo['isHoliday'],
      holidayName: holidayInfo['name'],
      tietKhi: getSolarTerm(date),
      gioCanChi: gioCanChi,
    );
  }

  static String getGioHoangDao(String chiDay) {
    if (chiDay.contains("Tý") || chiDay.contains("Ngọ"))
      return "Tý, Sửu, Mão, Ngọ, Thân, Dậu";
    return "Dần, Thìn, Tỵ, Thân, Dậu, Hợi";
  }

  static Map<String, String> getLoiKhuyen(DateTime date) {
    return TRUC_DATA[date.day % 12];
  }
}

class AppStyles {
  // Gradient thống nhất cho app
  static const LinearGradient primaryGradient = LinearGradient(
      colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight);

  static const double fabSize = 55.0;
  static const double fabBottomPos = 100.0;
  static const double cornerRadius = 24.0;
}

// ==========================================
// 3. MAIN APP & SCREEN
// ==========================================

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Theme Strategy: 0=System, 1=Manual, 2=Scheduled
  int _themeStrategy = 0;
  // Manual State: true=Dark, false=Light
  bool _isDarkManual = true;

  TimeOfDay _scheduleStart = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _scheduleEnd = const TimeOfDay(hour: 6, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeStrategy = prefs.getInt('themeStrategy') ?? 0;
      _isDarkManual = prefs.getBool('isDarkManual') ?? true;
      _scheduleStart = TimeOfDay(
          hour: prefs.getInt('themeStartH') ?? 18,
          minute: prefs.getInt('themeStartM') ?? 0);
      _scheduleEnd = TimeOfDay(
          hour: prefs.getInt('themeEndH') ?? 6,
          minute: prefs.getInt('themeEndM') ?? 0);
    });
  }

  Future<void> _updateThemeStrategy(int strategy) async {
    setState(() => _themeStrategy = strategy);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeStrategy', strategy);
  }

  Future<void> _updateManualTheme(bool isDark) async {
    setState(() => _isDarkManual = isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkManual', isDark);
  }

  Future<void> _updateSchedule(TimeOfDay start, TimeOfDay end) async {
    setState(() {
      _scheduleStart = start;
      _scheduleEnd = end;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeStartH', start.hour);
    await prefs.setInt('themeStartM', start.minute);
    await prefs.setInt('themeEndH', end.hour);
    await prefs.setInt('themeEndM', end.minute);
  }

  ThemeMode _getEffectiveThemeMode() {
    if (_themeStrategy == 0) return ThemeMode.system;
    if (_themeStrategy == 1)
      return _isDarkManual ? ThemeMode.dark : ThemeMode.light;

    // Scheduled Logic
    final now = TimeOfDay.now();
    final double nowMin = now.hour * 60.0 + now.minute;
    final double startMin = _scheduleStart.hour * 60.0 + _scheduleStart.minute;
    final double endMin = _scheduleEnd.hour * 60.0 + _scheduleEnd.minute;

    if (startMin < endMin) {
      return (nowMin >= startMin && nowMin < endMin)
          ? ThemeMode.dark
          : ThemeMode.light;
    } else {
      return (nowMin >= startMin || nowMin < endMin)
          ? ThemeMode.dark
          : ThemeMode.light;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Glass Calendar Pro',
      themeMode: _getEffectiveThemeMode(),
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        primaryColor: Colors.blueAccent,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueAccent, brightness: Brightness.light),
        textTheme:
            const TextTheme(bodyMedium: TextStyle(color: Color(0xFF333333))),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFF6DD5FA),
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueAccent, brightness: Brightness.dark),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      ),
      home: MainScreen(
        themeStrategy: _themeStrategy,
        isDarkManual: _isDarkManual,
        scheduleStart: _scheduleStart,
        scheduleEnd: _scheduleEnd,
        onStrategyChanged: _updateThemeStrategy,
        onManualChanged: _updateManualTheme,
        onScheduleChanged: _updateSchedule,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final int themeStrategy;
  final bool isDarkManual;
  final TimeOfDay scheduleStart;
  final TimeOfDay scheduleEnd;
  final Function(int) onStrategyChanged;
  final Function(bool) onManualChanged;
  final Function(TimeOfDay, TimeOfDay) onScheduleChanged;

  const MainScreen({
    super.key,
    required this.themeStrategy,
    required this.isDarkManual,
    required this.scheduleStart,
    required this.scheduleEnd,
    required this.onStrategyChanged,
    required this.onManualChanged,
    required this.onScheduleChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<String> _titles = [
    "Lịch Vạn Niên",
    "Việc Cần Làm",
    "Tìm Kiếm",
    "Cài Đặt"
  ];

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  StartingDayOfWeek _startingDayOfWeek = StartingDayOfWeek.monday;

  List<TodoTask> _tasks = [];
  bool _notifyFullMoon = true;
  bool _notifyHoliday = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final String? tasksJson = prefs.getString('tasks');
    if (tasksJson != null) {
      final List<dynamic> decoded = jsonDecode(tasksJson);
      setState(() {
        _tasks = decoded.map((e) => TodoTask.fromMap(e)).toList();
      });
    }

    final int? startDayIndex = prefs.getInt('startDay');
    if (startDayIndex != null) {
      setState(
          () => _startingDayOfWeek = StartingDayOfWeek.values[startDayIndex]);
    }

    setState(() {
      _notifyFullMoon = prefs.getBool('notifyFullMoon') ?? true;
      _notifyHoliday = prefs.getBool('notifyHoliday') ?? true;
      final int? hour = prefs.getInt('reminderHour');
      final int? minute = prefs.getInt('reminderMinute');
      if (hour != null && minute != null) {
        _reminderTime = TimeOfDay(hour: hour, minute: minute);
      }
    });
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_tasks.map((e) => e.toMap()).toList());
    await prefs.setString('tasks', encoded);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('startDay', _startingDayOfWeek.index);
    await prefs.setBool('notifyFullMoon', _notifyFullMoon);
    await prefs.setBool('notifyHoliday', _notifyHoliday);
    await prefs.setInt('reminderHour', _reminderTime.hour);
    await prefs.setInt('reminderMinute', _reminderTime.minute);
  }

  void _addTask(String title, DateTime date) {
    setState(() {
      _tasks.add(
          TodoTask(id: DateTime.now().toString(), title: title, date: date));
    });
    _saveTasks();
    _scheduleNotification(title);
  }

  void _toggleTask(String id) {
    setState(() {
      final index = _tasks.indexWhere((element) => element.id == id);
      if (index != -1) _tasks[index].isDone = !_tasks[index].isDone;
    });
    _saveTasks();
  }

  void _deleteTask(String id) {
    setState(() {
      _tasks.removeWhere((element) => element.id == id);
    });
    _saveTasks();
  }

  Future<void> _scheduleNotification(String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'task_channel',
      'Nhắc nhở công việc',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(
        0, 'Nhắc nhở công việc', body, details);
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  void _goToday() {
    setState(() {
      _selectedDay = DateTime.now();
      _focusedDay = DateTime.now();
    });
  }

  // --- DIALOG THÊM VIỆC (ĐÃ SỬA: GỌN HƠN) ---
  void _showAddTaskDialog() {
    final TextEditingController controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: GlassContainer(
            width: 320,
            height: null,
            borderRadius: 24,
            opacity: isDark ? 0.2 : 0.95,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Thêm công việc",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16),
                    maxLines: 5,
                    minLines: 3,
                    decoration: InputDecoration(
                        hintText: "Nhập nội dung...",
                        hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                                color:
                                    isDark ? Colors.white12 : Colors.black12)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                                color: Colors.blueAccent, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12)),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                          gradient: AppStyles.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF4FACFE).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        onPressed: () {
                          if (controller.text.isNotEmpty) {
                            _addTask(controller.text, _selectedDay);
                            Navigator.pop(context);
                          }
                        },
                        child: const Text("Lưu",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = isSameDay(_selectedDay, DateTime.now());

    final List<Widget> screens = [
      CalendarContent(
        focusedDay: _focusedDay,
        selectedDay: _selectedDay,
        onDaySelected: _onDaySelected,
        startingDayOfWeek: _startingDayOfWeek,
        tasks: _tasks,
        onDeleteTask: _deleteTask,
        onToggleTask: _toggleTask,
      ),
      TodoContent(
          tasks: _tasks,
          onDelete: _deleteTask,
          onToggle: _toggleTask,
          onAddTask: _showAddTaskDialog),
      SearchContent(tasks: _tasks),
      SettingsContent(
        themeStrategy: widget.themeStrategy,
        isDarkManual: widget.isDarkManual,
        scheduleStart: widget.scheduleStart,
        scheduleEnd: widget.scheduleEnd,
        onStrategyChanged: widget.onStrategyChanged,
        onManualChanged: widget.onManualChanged,
        onScheduleChanged: widget.onScheduleChanged,
        currentStartDay: _startingDayOfWeek,
        onStartDayChanged: (day) {
          setState(() => _startingDayOfWeek = day);
          _saveSettings();
        },
        notifyFullMoon: _notifyFullMoon,
        notifyHoliday: _notifyHoliday,
        reminderTime: _reminderTime,
        onToggleFullMoon: (val) {
          setState(() => _notifyFullMoon = val);
          _saveSettings();
        },
        onToggleHoliday: (val) {
          setState(() => _notifyHoliday = val);
          _saveSettings();
        },
        onReminderTimeChanged: (time) {
          setState(() => _reminderTime = time);
          _saveSettings();
        },
      ),
    ];

    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)])
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFE6E9F0)]);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // HEADER
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_titles[_selectedIndex],
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A))),
                          Container(
                              margin: const EdgeInsets.only(top: 4),
                              height: 4,
                              width: 40,
                              decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(2)))
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              top: 90,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 90),
                child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: screens[_selectedIndex]),
              ),
            ),

            if (_selectedIndex == 0 && !isToday)
              Positioned(
                bottom: AppStyles.fabBottomPos,
                right: 25,
                child: GestureDetector(
                  onTap: _goToday,
                  child: Container(
                    width: AppStyles.fabSize,
                    height: AppStyles.fabSize,
                    decoration: BoxDecoration(
                        gradient: AppStyles.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF4FACFE).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: Center(
                        child: Text("${DateTime.now().day}",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18))),
                  ),
                ),
              ),

            if (_selectedIndex == 1)
              Positioned(
                bottom: AppStyles.fabBottomPos,
                right: 25,
                child: GestureDetector(
                  onTap: _showAddTaskDialog,
                  child: Container(
                    width: AppStyles.fabSize,
                    height: AppStyles.fabSize,
                    decoration: BoxDecoration(
                        gradient: AppStyles.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF4FACFE).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: Icon(Icons.add, color: Colors.white, size: 30),
                  ),
                ),
              ),

            Positioned(
              bottom: 20,
              left: 30,
              right: 30,
              child: GlassContainer(
                width: double.infinity,
                height: 65,
                borderRadius: 35,
                blur: 25,
                opacity: isDark ? 0.15 : 0.7,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(Icons.calendar_month_rounded, 0, isDark),
                    _buildNavItem(
                        Icons.check_circle_outline_rounded, 1, isDark),
                    _buildNavItem(Icons.search_rounded, 2, isDark),
                    _buildNavItem(Icons.settings_rounded, 3, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05))
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: isSelected ? activeColor : inactiveColor, size: 24),
      ),
    );
  }
}

// ==========================================
// 4. CALENDAR CONTENT (Month Picker)
// ==========================================

class CalendarContent extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final StartingDayOfWeek startingDayOfWeek;
  final List<TodoTask> tasks;
  final Function(String) onDeleteTask;
  final Function(String) onToggleTask;

  const CalendarContent({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.startingDayOfWeek,
    required this.tasks,
    required this.onDeleteTask,
    required this.onToggleTask,
  });

  @override
  State<CalendarContent> createState() => _CalendarContentState();
}

class _CalendarContentState extends State<CalendarContent> {
  late LunarDateModel _lunarDate;
  late Map<String, String> _loiKhuyen;
  late String _gioHoangDao;

  @override
  void initState() {
    super.initState();
    _updateLunarInfo(widget.selectedDay);
  }

  @override
  void didUpdateWidget(covariant CalendarContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) {
      _updateLunarInfo(widget.selectedDay);
    }
  }

  void _updateLunarInfo(DateTime date) {
    setState(() {
      _lunarDate = LunarUtils.convertSolarToLunar(date);
      _loiKhuyen = LunarUtils.getLoiKhuyen(date);
      _gioHoangDao = LunarUtils.getGioHoangDao(_lunarDate.canChiDay);
    });
  }

  List<TodoTask> _getTasksForDay(DateTime day) {
    return widget.tasks.where((task) => isSameDay(task.date, day)).toList();
  }

  // --- SHOW MONTH YEAR PICKER ---
  void _showMonthYearPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        int tempYear = widget.focusedDay.year;
        int tempMonth = widget.focusedDay.month;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassContainer(
            width: 320,
            height: 350,
            borderRadius: 24,
            opacity: isDark ? 0.2 : 0.95,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text("Chọn Tháng & Năm",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black)),
                ),
                Expanded(
                  child: Row(
                    children: [
                      // YEAR
                      Expanded(
                          child: CupertinoPicker(
                              itemExtent: 40,
                              scrollController: FixedExtentScrollController(
                                  initialItem: tempYear - 2000),
                              onSelectedItemChanged: (int index) {
                                tempYear = 2000 + index;
                              },
                              children: List.generate(
                                  100,
                                  (index) => Center(
                                      child: Text("${2000 + index}",
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontSize: 18)))))),
                      // MONTH
                      Expanded(
                          child: CupertinoPicker(
                              itemExtent: 40,
                              scrollController: FixedExtentScrollController(
                                  initialItem: tempMonth - 1),
                              onSelectedItemChanged: (int index) {
                                tempMonth = index + 1;
                              },
                              children: List.generate(
                                  12,
                                  (index) => Center(
                                      child: Text("Tháng ${index + 1}",
                                          style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontSize: 18)))))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                          gradient: AppStyles.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF4FACFE).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]),
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          onPressed: () {
                            final newDate = DateTime(tempYear, tempMonth, 1);
                            widget.onDaySelected(newDate, newDate);
                            Navigator.pop(context);
                          },
                          child: const Text("Xác nhận",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16))),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
    final subColor = isDark ? Colors.white60 : const Color(0xFF636E72);
    final selectedDayTasks = _getTasksForDay(widget.selectedDay);

    return Center(
      child: SingleChildScrollView(
        child: Column(
          children: [
            GlassContainer(
              width: MediaQuery.of(context).size.width * 0.9,
              borderRadius: AppStyles.cornerRadius,
              opacity: isDark ? 0.1 : 0.7,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
                child: TableCalendar(
                  firstDay: DateTime.utc(2000, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: widget.focusedDay,
                  selectedDayPredicate: (day) =>
                      isSameDay(widget.selectedDay, day),
                  onDaySelected: widget.onDaySelected,
                  locale: 'vi_VN',
                  startingDayOfWeek: widget.startingDayOfWeek,
                  rowHeight: 62,
                  daysOfWeekHeight: 45,
                  eventLoader: (day) => _getTasksForDay(day),
                  onHeaderTapped: (focusedDay) => _showMonthYearPicker(context),
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextFormatter: (date, locale) =>
                        "Tháng ${date.month} / ${date.year}",
                    titleTextStyle: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: 0.5),
                    leftChevronIcon: _buildChevron(
                        isDark, Icons.chevron_left_rounded, textColor),
                    rightChevronIcon: _buildChevron(
                        isDark, Icons.chevron_right_rounded, textColor),
                    headerPadding: const EdgeInsets.only(bottom: 20),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    dowTextFormatter: (date, locale) =>
                        DateFormat.E(locale).format(date)[0].toUpperCase() +
                        DateFormat.E(locale).format(date).substring(1),
                    weekdayStyle: TextStyle(
                        color: subColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    weekendStyle: TextStyle(
                        color: Colors.redAccent.withOpacity(0.7),
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) =>
                        _buildCustomDayCell(day, isDark, false),
                    selectedBuilder: (context, day, focusedDay) =>
                        _buildCustomDayCell(day, isDark, true),
                    todayBuilder: (context, day, focusedDay) =>
                        _buildCustomDayCell(day, isDark, false, isToday: true),
                    outsideBuilder: (context, day, focusedDay) => Opacity(
                        opacity: 0.2,
                        child: _buildCustomDayCell(day, isDark, false)),
                    markerBuilder: (context, day, events) {
                      final hasTask =
                          widget.tasks.any((t) => isSameDay(t.date, day));
                      if (events.isEmpty && !hasTask) return null;
                      return Positioned(
                        bottom: 5,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasTask)
                              Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5),
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GlassContainer(
              width: MediaQuery.of(context).size.width * 0.9,
              borderRadius: AppStyles.cornerRadius,
              opacity: isDark ? 0.1 : 0.7,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (_lunarDate.isHoliday)
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.3))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.celebration,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(_lunarDate.holidayName.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ]),
                      ),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("ÂM LỊCH",
                                    style: TextStyle(
                                        color: subColor,
                                        fontSize: 12,
                                        letterSpacing: 1.5,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text("${_lunarDate.day}",
                                    style: TextStyle(
                                        fontSize: 56,
                                        fontWeight: FontWeight.w300,
                                        color: textColor,
                                        height: 1.0)),
                                if (_lunarDate.isLeap)
                                  Text("(Nhuận)",
                                      style: TextStyle(
                                          color: subColor, fontSize: 12)),
                              ]),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildTag(isDark, _lunarDate.canChiDay),
                                const SizedBox(height: 8),
                                Text(
                                    "Tháng ${_lunarDate.month} · ${_lunarDate.canChiMonth}",
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor)),
                                Text("Năm ${_lunarDate.canChiYear}",
                                    style: TextStyle(
                                        fontSize: 14, color: subColor)),
                                const SizedBox(height: 8),
                                if (_lunarDate.tietKhi.isNotEmpty)
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Colors.blueAccent
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text("Tiết ${_lunarDate.tietKhi}",
                                          style: TextStyle(
                                              color: Colors.blueAccent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)))
                              ]),
                        ]),
                    const SizedBox(height: 20),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16)),
                        child: Column(children: [
                          Row(children: [
                            Icon(Icons.access_time_filled,
                                color: Colors.blueAccent, size: 18),
                            const SizedBox(width: 8),
                            Text("Giờ hiện tại: ",
                                style:
                                    TextStyle(fontSize: 12, color: subColor)),
                            Text(_lunarDate.gioCanChi,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textColor))
                          ]),
                          const Divider(height: 16, color: Colors.white10),
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.stars_rounded,
                                    color: Colors.amber[400], size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text("Giờ Hoàng Đạo",
                                          style: TextStyle(
                                              fontSize: 11, color: subColor)),
                                      Text(_gioHoangDao,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: textColor))
                                    ]))
                              ]),
                        ])),
                    const SizedBox(height: 20),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child:
                                  _buildDosDontsBox(true, _loiKhuyen['tot']!)),
                          const SizedBox(width: 12),
                          Expanded(
                              child:
                                  _buildDosDontsBox(false, _loiKhuyen['xau']!))
                        ]),
                    const SizedBox(height: 25),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Row(children: [
                          Icon(Icons.check_circle_outline,
                              size: 16, color: subColor),
                          const SizedBox(width: 8),
                          Text("Công việc hôm nay",
                              style: TextStyle(
                                  color: subColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold))
                        ])),
                    const SizedBox(height: 10),
                    if (selectedDayTasks.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text("Chưa có công việc nào",
                              style: TextStyle(
                                  color: subColor,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic)))
                    else
                      ...selectedDayTasks.map((task) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 0),
                              leading: GestureDetector(
                                onTap: () => widget.onToggleTask(task.id),
                                child: Icon(
                                    task.isDone
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color:
                                        task.isDone ? Colors.green : subColor,
                                    size: 20),
                              ),
                              title: Text(task.title,
                                  style: TextStyle(
                                      decoration: task.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: textColor,
                                      fontSize: 14)),
                              trailing: GestureDetector(
                                onTap: () => widget.onDeleteTask(task.id),
                                child: Icon(Icons.close,
                                    size: 16, color: subColor),
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildChevron(bool isDark, IconData icon, Color color) {
    return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20));
  }

  Widget _buildCustomDayCell(DateTime date, bool isDark, bool isSelected,
      {bool isToday = false}) {
    final lunarInfo = LunarUtils.convertSolarToLunar(date);
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isHoliday = lunarInfo.isHoliday;

    Color dayColor = isDark ? Colors.white : Colors.black87;
    Color lunarColor = isDark ? Colors.white38 : Colors.black45;

    if (isHoliday) {
      dayColor = Colors.redAccent;
    } else if (isWeekend) {
      dayColor = const Color(0xFFFF6B6B);
    }

    if (isSelected) {
      dayColor = Colors.white;
      lunarColor = Colors.white70;
    }

    return Center(
        child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: isSelected
                ? BoxDecoration(
                    gradient: AppStyles.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF4FACFE).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                      ])
                : isToday
                    ? BoxDecoration(
                        border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.6),
                            width: 1.5),
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.blueAccent.withOpacity(0.05))
                    : null,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${date.day}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: dayColor)),
              const SizedBox(height: 2),
              Text('${lunarInfo.day}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: lunarColor))
            ])));
  }

  Widget _buildTag(bool isDark, String text) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: isDark ? Colors.white24 : Colors.black12)),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87)));
  }

  Widget _buildDosDontsBox(bool isGood, String text) {
    final colorBase = isGood ? Colors.green : Colors.red;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: colorBase.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorBase.withOpacity(0.2), width: 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isGood ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                size: 14, color: colorBase),
            const SizedBox(width: 8),
            Text(isGood ? "Nên" : "Kỵ",
                style: TextStyle(
                    color: colorBase,
                    fontWeight: FontWeight.bold,
                    fontSize: 13))
          ]),
          const SizedBox(height: 8),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: colorBase.withOpacity(0.8),
                  fontWeight: FontWeight.w500))
        ]));
  }
}

// ==========================================
// 5. TO-DO LIST CONTENT
// ==========================================
class TodoContent extends StatefulWidget {
  final List<TodoTask> tasks;
  final Function(String) onDelete;
  final Function(String) onToggle;
  final Function() onAddTask;

  const TodoContent(
      {super.key,
      required this.tasks,
      required this.onDelete,
      required this.onToggle,
      required this.onAddTask});
  @override
  State<TodoContent> createState() => TodoContentState();
}

class TodoContentState extends State<TodoContent> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            GlassContainer(
                width: double.infinity,
                height: 60,
                borderRadius: AppStyles.cornerRadius,
                opacity: isDark ? 0.1 : 0.7,
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Danh sách việc",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87)),
                          Text(
                              "${widget.tasks.where((t) => t.isDone).length}/${widget.tasks.length}",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent))
                        ]))),
            const SizedBox(height: 15),
            Expanded(
                child: ListView.builder(
                    itemCount: widget.tasks.length,
                    itemBuilder: (context, index) {
                      final task = widget.tasks[index];
                      return Dismissible(
                          key: Key(task.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) => widget.onDelete(task.id),
                          background: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.delete_outline,
                                  color: Colors.white)),
                          child: GestureDetector(
                              onTap: () {},
                              child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: GlassContainer(
                                      width: double.infinity,
                                      borderRadius: 16,
                                      opacity: isDark ? 0.1 : 0.7,
                                      child: ListTile(
                                          leading: GestureDetector(
                                              onTap: () =>
                                                  widget.onToggle(task.id),
                                              child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                      color: task.isDone
                                                          ? Colors.blueAccent
                                                          : Colors.transparent,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: task.isDone
                                                              ? Colors
                                                                  .blueAccent
                                                              : (isDark ? Colors.white54 : Colors.black38),
                                                          width: 2)),
                                                  child: task.isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null)),
                                          title: Text(task.title, style: TextStyle(decoration: task.isDone ? TextDecoration.lineThrough : null, color: isDark ? (task.isDone ? Colors.white38 : Colors.white) : (task.isDone ? Colors.black38 : Colors.black87))),
                                          subtitle: Text(DateFormat('dd/MM/yyyy').format(task.date), style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.black38)))))));
                    })),
          ]))
    ]);
  }
}

// ==========================================
// 6. SEARCH CONTENT
// ==========================================
class SearchContent extends StatefulWidget {
  final List<TodoTask> tasks;
  const SearchContent({super.key, required this.tasks});
  @override
  State<SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<SearchContent> {
  String _keyword = "";
  final TextEditingController _controller = TextEditingController();

  List<dynamic> get _filteredResults {
    if (_keyword.isEmpty) return [];

    final holidays = LunarUtils.HOLIDAYS_DATA
        .where((h) => h['name'].toLowerCase().contains(_keyword.toLowerCase()))
        .toList();

    final todos = widget.tasks
        .where((t) => t.title.toLowerCase().contains(_keyword.toLowerCase()))
        .toList();

    return [...holidays, ...todos];
  }

  void _showHolidayDetail(BuildContext context, Map<String, dynamic> holiday) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
    final subColor = isDark ? Colors.white60 : const Color(0xFF636E72);
    final randomAdvice = LunarUtils.TRUC_DATA[holiday['day'] % 12];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: GlassContainer(
          width: double.infinity,
          height: null,
          borderRadius: 24,
          opacity: isDark ? 0.2 : 0.95,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.celebration,
                        color: Colors.redAccent, size: 40)),
                const SizedBox(height: 16),
                Text(holiday['name'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.5)),
                const SizedBox(height: 24),
                Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 30),
                    decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12)),
                    child: Column(children: [
                      Text("${holiday['day']}",
                          style: const TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                              height: 1.0)),
                      Text("Tháng ${holiday['month']}",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: textColor)),
                      const SizedBox(height: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: holiday['type'] == 'lunar'
                                  ? Colors.orangeAccent.withOpacity(0.2)
                                  : Colors.blueAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(
                              holiday['type'] == 'lunar'
                                  ? "Lịch Âm"
                                  : "Lịch Dương",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: holiday['type'] == 'lunar'
                                      ? Colors.orangeAccent
                                      : Colors.blueAccent)))
                    ])),
                const SizedBox(height: 24),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Thông tin chi tiết",
                        style: TextStyle(
                            color: subColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Text(holiday['desc'] ?? "Đang cập nhật...",
                    style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontSize: 14,
                        height: 1.5),
                    textAlign: TextAlign.justify),
                const SizedBox(height: 24),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child:
                          _buildDetailDosDontsBox(true, randomAdvice['tot']!)),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          _buildDetailDosDontsBox(false, randomAdvice['xau']!))
                ]),
                const SizedBox(height: 30),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                        onPressed: () => Navigator.pop(context),
                        child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                                gradient: AppStyles.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                      color: const Color(0xFF4FACFE)
                                          .withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3))
                                ]),
                            child: Text("Đóng",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailDosDontsBox(bool isGood, String text) {
    final colorBase = isGood ? Colors.green : Colors.red;
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: colorBase.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorBase.withOpacity(0.2), width: 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isGood ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                size: 14, color: colorBase),
            const SizedBox(width: 6),
            Text(isGood ? "Nên" : "Kỵ",
                style: TextStyle(
                    color: colorBase,
                    fontWeight: FontWeight.bold,
                    fontSize: 13))
          ]),
          const SizedBox(height: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: colorBase.withOpacity(0.8),
                  fontWeight: FontWeight.w500))
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          GlassContainer(
              width: double.infinity,
              height: 60,
              borderRadius: 16,
              opacity: isDark ? 0.1 : 0.7,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(children: [
                    Icon(Icons.search,
                        color: isDark ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(
                            controller: _controller,
                            onChanged: (val) => setState(() => _keyword = val),
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                                hintText: "Tìm ngày lễ hoặc công việc...",
                                hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.black38),
                                border: InputBorder.none))),
                    if (_keyword.isNotEmpty)
                      GestureDetector(
                          onTap: () {
                            _controller.clear();
                            setState(() => _keyword = "");
                          },
                          child: Icon(Icons.close,
                              color: isDark ? Colors.white54 : Colors.black45,
                              size: 20))
                  ]))),
          const SizedBox(height: 20),
          Expanded(
              child: ListView.builder(
                  itemCount: _filteredResults.length,
                  itemBuilder: (context, index) {
                    final item = _filteredResults[index];
                    final isHoliday = item is Map<String, dynamic>;

                    if (isHoliday) {
                      final isLunar = item['type'] == 'lunar';
                      return GestureDetector(
                          onTap: () => _showHolidayDetail(context, item),
                          child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: GlassContainer(
                                  width: double.infinity,
                                  borderRadius: 16,
                                  opacity: isDark ? 0.1 : 0.7,
                                  child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 4),
                                      leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                              color: isLunar
                                                  ? Colors.orangeAccent
                                                      .withOpacity(0.1)
                                                  : Colors.blueAccent
                                                      .withOpacity(0.1),
                                              shape: BoxShape.circle),
                                          child:
                                              Icon(isLunar ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
                                                  color: isLunar
                                                      ? Colors.orangeAccent
                                                      : Colors.blueAccent,
                                                  size: 24)),
                                      title: Text(item['name'],
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                              fontSize: 16)),
                                      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text("Ngày ${item['day']}/${item['month']}", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13))),
                                      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26)))));
                    } else {
                      final task = item as TodoTask;
                      return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: GlassContainer(
                              width: double.infinity,
                              borderRadius: 16,
                              opacity: isDark ? 0.1 : 0.7,
                              child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          shape: BoxShape.circle),
                                      child: const Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.green,
                                          size: 24)),
                                  title: Text(task.title,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontSize: 16)),
                                  subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                          "Ngày ${DateFormat('dd/MM').format(task.date)}",
                                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13))),
                                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26))));
                    }
                  }))
        ]));
  }
}

// ==========================================
// 7. SETTINGS CONTENT (UPDATED: CUSTOM SWITCH)
// ==========================================

class SettingsContent extends StatefulWidget {
  final int themeStrategy;
  final bool isDarkManual;
  final TimeOfDay scheduleStart;
  final TimeOfDay scheduleEnd;
  final Function(int) onStrategyChanged;
  final Function(bool) onManualChanged;
  final Function(TimeOfDay, TimeOfDay) onScheduleChanged;

  final StartingDayOfWeek currentStartDay;
  final Function(StartingDayOfWeek) onStartDayChanged;
  final bool notifyFullMoon;
  final bool notifyHoliday;
  final Function(bool) onToggleFullMoon;
  final Function(bool) onToggleHoliday;
  final TimeOfDay reminderTime;
  final Function(TimeOfDay) onReminderTimeChanged;

  const SettingsContent({
    super.key,
    required this.themeStrategy,
    required this.isDarkManual,
    required this.scheduleStart,
    required this.scheduleEnd,
    required this.onStrategyChanged,
    required this.onManualChanged,
    required this.onScheduleChanged,
    required this.currentStartDay,
    required this.onStartDayChanged,
    required this.notifyFullMoon,
    required this.notifyHoliday,
    required this.onToggleFullMoon,
    required this.onToggleHoliday,
    required this.reminderTime,
    required this.onReminderTimeChanged,
  });

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {
  // --- WIDGET SWITCH DÙNG CHUNG ---
  // Sử dụng GlassSwitch tùy chỉnh để đồng bộ với AppStyles.primaryGradient
  Widget _buildSwitchItem(
      {required String title,
      required IconData icon,
      required bool value,
      required Function(bool) onChanged,
      required bool isDark}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color:
                  isDark ? Colors.white10 : Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle),
          child: Icon(icon,
              color: isDark ? Colors.white : Colors.blueAccent, size: 20)),
      title: Text(title,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600)),
      // Sử dụng GlassSwitch thay vì CupertinoSwitch mặc định
      trailing: GlassSwitch(value: value, onChanged: onChanged),
    );
  }

  void _showVersionInfo(BuildContext context, bool isDark) {
    showDialog(
        context: context,
        builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              child: GlassContainer(
                width: 320,
                height: null,
                borderRadius: 24,
                opacity: isDark ? 0.2 : 0.95,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            gradient: AppStyles.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      const Color(0xFF4FACFE).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ]),
                        child: const Icon(Icons.calendar_month_rounded,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text("Glass Calendar Pro",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 4),
                      Text("Phiên bản 1.0.0 (Beta)",
                          style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.black54)),
                      const SizedBox(height: 20),
                      Text(
                          "Ứng dụng Lịch Vạn Niên với giao diện kính mờ hiện đại. Hỗ trợ xem ngày âm dương, ngày lễ, giờ hoàng đạo và quản lý công việc cá nhân.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark ? Colors.white70 : Colors.black87)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16))),
                            onPressed: () => Navigator.pop(ctx),
                            child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                    gradient: AppStyles.primaryGradient,
                                    borderRadius: BorderRadius.circular(16)),
                                child: const Text("Đóng",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)))),
                      ),
                    ],
                  ),
                ),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildSectionHeader("Giao diện", isDark),
          GlassContainer(
            width: double.infinity,
            borderRadius: AppStyles.cornerRadius,
            opacity: isDark ? 0.1 : 0.7,
            child: Column(children: [
              _buildThemeOption(0, "Theo hệ thống (Mặc định)",
                  Icons.settings_system_daydream, isDark),
              Divider(
                  height: 1, color: isDark ? Colors.white10 : Colors.black12),
              _buildThemeOption(1, "Thủ công (Sáng/Tối)", Icons.tune, isDark),
              if (widget.themeStrategy == 1)
                _buildSwitchItem(
                    title: "Bật chế độ tối",
                    icon: Icons.dark_mode,
                    value: widget.isDarkManual,
                    onChanged: widget.onManualChanged,
                    isDark: isDark),
              Divider(
                  height: 1, color: isDark ? Colors.white10 : Colors.black12),
              _buildThemeOption(2, "Theo lịch trình", Icons.schedule, isDark),
              if (widget.themeStrategy == 2)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimePickerButton(
                          "Bắt đầu (Tối)",
                          widget.scheduleStart,
                          (t) =>
                              widget.onScheduleChanged(t, widget.scheduleEnd),
                          isDark),
                      const Icon(Icons.arrow_forward,
                          size: 16, color: Colors.grey),
                      _buildTimePickerButton(
                          "Kết thúc (Sáng)",
                          widget.scheduleEnd,
                          (t) =>
                              widget.onScheduleChanged(widget.scheduleStart, t),
                          isDark),
                    ],
                  ),
                ),
              Divider(
                  height: 1, color: isDark ? Colors.white10 : Colors.black12),
              _buildActionItem(
                  icon: Icons.calendar_today,
                  title: "Tuần bắt đầu vào",
                  subtitle: widget.currentStartDay == StartingDayOfWeek.monday
                      ? "Thứ Hai"
                      : "Chủ Nhật",
                  isDark: isDark,
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: GlassContainer(
                                width: 300,
                                height: 180,
                                borderRadius: 20,
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ListTile(
                                          title: Text("Thứ Hai",
                                              style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black)),
                                          trailing: widget.currentStartDay ==
                                                  StartingDayOfWeek.monday
                                              ? const Icon(Icons.check,
                                                  color: Colors.blueAccent)
                                              : null,
                                          onTap: () {
                                            widget.onStartDayChanged(
                                                StartingDayOfWeek.monday);
                                            Navigator.pop(context);
                                          }),
                                      Divider(
                                          height: 1,
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black12),
                                      ListTile(
                                          title: Text("Chủ Nhật",
                                              style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black)),
                                          trailing: widget.currentStartDay ==
                                                  StartingDayOfWeek.sunday
                                              ? const Icon(Icons.check,
                                                  color: Colors.blueAccent)
                                              : null,
                                          onTap: () {
                                            widget.onStartDayChanged(
                                                StartingDayOfWeek.sunday);
                                            Navigator.pop(context);
                                          }),
                                    ]))));
                  }),
            ]),
          ),
          const SizedBox(height: 25),
          _buildSectionHeader("Thông báo & Nhắc nhở", isDark),
          GlassContainer(
            width: double.infinity,
            borderRadius: AppStyles.cornerRadius,
            opacity: isDark ? 0.1 : 0.7,
            child: Column(children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.blueAccent.withOpacity(0.1),
                              shape: BoxShape.circle),
                          child: Icon(Icons.access_time_filled,
                              color: isDark ? Colors.white : Colors.blueAccent,
                              size: 20)),
                      const SizedBox(width: 16),
                      Text("Giờ nhắc nhở",
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                    ]),
                    GestureDetector(
                      onTap: () async {
                        showDialog(
                            context: context,
                            builder: (context) {
                              TimeOfDay tempTime = widget.reminderTime;
                              return Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: GlassContainer(
                                      width: 320,
                                      height: 350,
                                      borderRadius: 24,
                                      opacity: isDark ? 0.2 : 0.95,
                                      child: Column(children: [
                                        Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Text("Chọn giờ nhắc",
                                                style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black))),
                                        Expanded(
                                            child: CupertinoTheme(
                                                data: CupertinoThemeData(
                                                    brightness: isDark
                                                        ? Brightness.dark
                                                        : Brightness.light,
                                                    textTheme: CupertinoTextThemeData(
                                                        dateTimePickerTextStyle:
                                                            TextStyle(
                                                                color: isDark
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black,
                                                                fontSize: 20))),
                                                child: CupertinoDatePicker(
                                                    mode:
                                                        CupertinoDatePickerMode
                                                            .time,
                                                    initialDateTime: DateTime(
                                                        2024,
                                                        1,
                                                        1,
                                                        widget
                                                            .reminderTime.hour,
                                                        widget.reminderTime
                                                            .minute),
                                                    onDateTimeChanged: (val) {
                                                      tempTime = TimeOfDay(
                                                          hour: val.hour,
                                                          minute: val.minute);
                                                    },
                                                    use24hFormat: true))),
                                        Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.transparent,
                                                        shadowColor:
                                                            Colors.transparent,
                                                        padding:
                                                            EdgeInsets.zero,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    12))),
                                                    onPressed: () {
                                                      widget
                                                          .onReminderTimeChanged(
                                                              tempTime);
                                                      Navigator.pop(context);
                                                    },
                                                    child: Container(
                                                        width: double.infinity,
                                                        padding: const EdgeInsets.symmetric(
                                                            vertical: 12),
                                                        decoration: BoxDecoration(
                                                            gradient: AppStyles
                                                                .primaryGradient,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    12)),
                                                        child: const Text("Xác nhận",
                                                            textAlign: TextAlign.center,
                                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))))
                                      ])));
                            });
                      },
                      child: GlassContainer(
                          width: 80,
                          height: 36,
                          borderRadius: 10,
                          opacity: 0.3,
                          child: Center(
                              child: Text(
                                  "${widget.reminderTime.hour.toString().padLeft(2, '0')}:${widget.reminderTime.minute.toString().padLeft(2, '0')}",
                                  style: TextStyle(
                                      color:
                                          isDark ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)))),
                    )
                  ],
                ),
              ),
              Divider(
                  height: 1, color: isDark ? Colors.white10 : Colors.black12),
              _buildSwitchItem(
                  title: "Nhắc Rằm / Mùng 1",
                  icon: Icons.notifications_active,
                  value: widget.notifyFullMoon,
                  onChanged: widget.onToggleFullMoon,
                  isDark: isDark),
              Divider(
                  height: 1, color: isDark ? Colors.white10 : Colors.black12),
              _buildSwitchItem(
                  title: "Nhắc ngày lễ tết",
                  icon: Icons.celebration,
                  value: widget.notifyHoliday,
                  onChanged: widget.onToggleHoliday,
                  isDark: isDark),
            ]),
          ),
          const SizedBox(height: 25),
          _buildSectionHeader("Khác", isDark),
          GlassContainer(
            width: double.infinity,
            borderRadius: AppStyles.cornerRadius,
            opacity: isDark ? 0.1 : 0.7,
            child: Column(children: [
              _buildActionItem(
                  icon: Icons.info_outline,
                  title: "Phiên bản",
                  subtitle: "1.0.0 (Beta)",
                  isDark: isDark,
                  onTap: () => _showVersionInfo(context, isDark)),
            ]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildThemeOption(int type, String title, IconData icon, bool isDark) {
    final isSelected = widget.themeStrategy == type;
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color:
                  isDark ? Colors.white10 : Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle),
          child: Icon(icon,
              color: isDark ? Colors.white : Colors.blueAccent, size: 20)),
      title: Text(title,
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600)),
      trailing:
          isSelected ? const Icon(Icons.check, color: Colors.blueAccent) : null,
      onTap: () => widget.onStrategyChanged(type),
    );
  }

  Widget _buildTimePickerButton(
      String label, TimeOfDay time, Function(TimeOfDay) onSelect, bool isDark) {
    return GestureDetector(
      onTap: () async {
        showDialog(
            context: context,
            builder: (context) {
              TimeOfDay temp = time;
              return Dialog(
                  backgroundColor: Colors.transparent,
                  child: GlassContainer(
                      width: 300,
                      height: 300,
                      borderRadius: 20,
                      opacity: 0.95,
                      child: Column(children: [
                        Expanded(
                            child: CupertinoTheme(
                                data: CupertinoThemeData(
                                    brightness: isDark
                                        ? Brightness.dark
                                        : Brightness.light),
                                child: CupertinoDatePicker(
                                    mode: CupertinoDatePickerMode.time,
                                    initialDateTime: DateTime(
                                        2024, 1, 1, time.hour, time.minute),
                                    onDateTimeChanged: (val) => temp =
                                        TimeOfDay(
                                            hour: val.hour,
                                            minute: val.minute)))),
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12))),
                                    onPressed: () {
                                      onSelect(temp);
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                            gradient: AppStyles.primaryGradient,
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: const Text("OK",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight:
                                                    FontWeight.bold))))))
                      ])));
            });
      },
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 12)),
          const SizedBox(height: 4),
          GlassContainer(
              width: 80,
              height: 36,
              borderRadius: 10,
              opacity: 0.3,
              child: Center(
                  child: Text(
                      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 10, bottom: 10),
        child: Text(title.toUpperCase(),
            style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)));
  }

  Widget _buildSettingItem(
      {required IconData icon,
      required String title,
      String? subtitle,
      required bool isDark,
      required Widget trailing}) {
    return ListTile(
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: isDark
                    ? Colors.white10
                    : Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(icon,
                color: isDark ? Colors.white : Colors.blueAccent, size: 20)),
        title: Text(title,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 12))
            : null,
        trailing: trailing);
  }

  Widget _buildActionItem(
      {required IconData icon,
      required String title,
      String? subtitle,
      required bool isDark,
      required VoidCallback onTap}) {
    return ListTile(
        onTap: onTap,
        leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: isDark
                    ? Colors.white10
                    : Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(icon,
                color: isDark ? Colors.white : Colors.blueAccent, size: 20)),
        title: Text(title,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 12))
            : null,
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: isDark ? Colors.white30 : Colors.black26));
  }
}

// ==========================================
// 8. GLOBAL HELPER WIDGETS
// ==========================================

class PlaceholderGlass extends StatelessWidget {
  final String text;
  final IconData icon;
  const PlaceholderGlass({super.key, required this.text, required this.icon});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
        child: GlassContainer(
            width: 250,
            height: 200,
            opacity: isDark ? 0.1 : 0.7,
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon,
                  size: 50, color: isDark ? Colors.white24 : Colors.black26),
              const SizedBox(height: 16),
              Text(text,
                  style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontSize: 16))
            ])));
  }
}

// --- WIDGET SWITCH TÙY CHỈNH ĐỂ ĐỒNG BỘ MÀU SẮC ---
class GlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const GlassSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: value ? AppStyles.primaryGradient : null,
          color: value ? null : Colors.grey.withOpacity(0.4),
          boxShadow: [
            BoxShadow(
              color: value
                  ? const Color(0xFF4FACFE).withOpacity(0.4)
                  : Colors.transparent,
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassContainer extends StatelessWidget {
  final double width;
  final double? height;
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  const GlassContainer(
      {super.key,
      required this.width,
      this.height,
      required this.child,
      this.borderRadius = 20.0,
      this.blur = 15.0,
      this.opacity = 0.1});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark ? Colors.white : Colors.white;
    final borderColor =
        isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6);
    return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(children: [
          Positioned.fill(
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                    decoration: BoxDecoration(
                        color: glassColor.withOpacity(isDark ? opacity : 0.7),
                        borderRadius: BorderRadius.circular(borderRadius),
                        border: Border.all(color: borderColor, width: 0.5),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ],
                        gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.01)
                                  ]
                                : [
                                    Colors.white.withOpacity(0.8),
                                    Colors.white.withOpacity(0.6)
                                  ],
                            stops: const [0.0, 1.0])))),
          ),
          Container(
              width: width,
              height: height,
              padding: EdgeInsets.zero,
              child: child),
        ]));
  }
}
