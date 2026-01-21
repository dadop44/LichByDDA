import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vnlunar/vnlunar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
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
  DateTime startTime; // Thay đổi: Thời gian bắt đầu
  DateTime endTime;   // Thay đổi: Thời gian kết thúc
  String tag;
  int reminderMinutes;

  TodoTask({
    required this.id, 
    required this.title, 
    this.isDone = false, 
    required this.startTime,
    required this.endTime,
    this.tag = "Lời nhắc",
    this.reminderMinutes = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 
      'title': title, 
      'isDone': isDone, 
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'tag': tag,
      'reminderMinutes': reminderMinutes
    };
  }

  factory TodoTask.fromMap(Map<String, dynamic> map) {
    // Xử lý tương thích ngược cho dữ liệu cũ (chỉ có 'date')
    DateTime start = map['startTime'] != null 
        ? DateTime.parse(map['startTime']) 
        : (map['date'] != null ? DateTime.parse(map['date']) : DateTime.now());
        
    DateTime end = map['endTime'] != null 
        ? DateTime.parse(map['endTime']) 
        : start.add(const Duration(hours: 1)); // Mặc định 1 tiếng nếu không có end

    return TodoTask(
      id: map['id'], 
      title: map['title'], 
      isDone: map['isDone'], 
      startTime: start,
      endTime: end,
      tag: map['tag'] ?? "Lời nhắc",
      reminderMinutes: map['reminderMinutes'] ?? 0
    );
  }
}

class TaskTags {
  static const Map<String, Color> tags = {
    "Công việc": Colors.blueAccent,
    "Sự kiện": Colors.purpleAccent,
    "Sinh nhật": Colors.pinkAccent,
    "Lời nhắc": Colors.orangeAccent,
    "Gia đình": Colors.green,
  };
  
  static const Map<String, IconData> icons = {
    "Công việc": Icons.work_outline,
    "Sự kiện": Icons.star_outline,
    "Sinh nhật": Icons.cake_outlined,
    "Lời nhắc": Icons.notifications_none,
    "Gia đình": Icons.home_outlined,
  };
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
    required this.day, required this.month, required this.year, required this.isLeap,
    required this.canChiDay, required this.canChiMonth, required this.canChiYear,
    this.isHoliday = false, this.holidayName = "",
    this.tietKhi = "", this.gioCanChi = "",
  });
}

class LunarUtils {
  static final List<String> CAN = ["Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý"];
  static final List<String> CHI = ["Tý", "Sửu", "Dần", "Mão", "Thìn", "Tỵ", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi"];
  
  static final List<Map<String, String>> THAP_NHI_TRUC = [
    {"name": "Kiến", "tot": "Xuất hành, giá thú, an táng", "xau": "Động thổ, đào giếng"},
    {"name": "Trừ", "tot": "Tẩy uế, chữa bệnh, tế lễ", "xau": "Cưới hỏi, đi xa, ký kết"},
    {"name": "Mãn", "tot": "Cầu tài, khai trương, xuất hành", "xau": "An táng, tố tụng"},
    {"name": "Bình", "tot": "Sửa nhà, nhập trạch, làm đường", "xau": "Kiện tụng, an táng"},
    {"name": "Định", "tot": "Nhập học, mua gia súc, động thổ", "xau": "Kiện tụng, xuất hành"},
    {"name": "Chấp", "tot": "Lập khế ước, tế lễ", "xau": "Xuất tiền, dời nhà"},
    {"name": "Phá", "tot": "Phá dỡ nhà, trị bệnh", "xau": "Mọi việc (trừ phá dỡ)"},
    {"name": "Nguy", "tot": "Lễ bái, an táng", "xau": "Đi thuyền, leo cao, khởi công"},
    {"name": "Thành", "tot": "Khai trương, cưới hỏi, nhập học", "xau": "Kiện tụng, tranh chấp"},
    {"name": "Thu", "tot": "Thu tiền, nạp tài, trồng trọt", "xau": "An táng, xuất hành"},
    {"name": "Khai", "tot": "Động thổ, cưới hỏi, làm nhà", "xau": "Chôn cất, động quan"},
    {"name": "Bế", "tot": "Đắp đê, lấp hố, an táng", "xau": "Chữa bệnh (mắt), cưới hỏi"},
  ];

  static final List<Map<String, dynamic>> HOLIDAYS_DATA = [
    {"name": "Tết Dương Lịch", "day": 1, "month": 1, "type": "solar", "desc": "Ngày đầu tiên của năm mới Dương lịch."},
    {"name": "Lễ Tình Nhân", "day": 14, "month": 2, "type": "solar", "desc": "Ngày lễ tôn vinh tình yêu đôi lứa."},
    {"name": "Quốc tế Phụ nữ", "day": 8, "month": 3, "type": "solar", "desc": "Ngày tôn vinh phụ nữ trên toàn thế giới."},
    {"name": "Giải phóng Miền Nam", "day": 30, "month": 4, "type": "solar", "desc": "Kỷ niệm ngày thống nhất đất nước Việt Nam."},
    {"name": "Quốc tế Lao Động", "day": 1, "month": 5, "type": "solar", "desc": "Ngày hội của người lao động toàn cầu."},
    {"name": "Quốc tế Thiếu nhi", "day": 1, "month": 6, "type": "solar", "desc": "Ngày tết dành riêng cho trẻ em."},
    {"name": "Thương binh Liệt sĩ", "day": 27, "month": 7, "type": "solar", "desc": "Ngày tưởng nhớ các anh hùng liệt sĩ."},
    {"name": "Quốc Khánh", "day": 2, "month": 9, "type": "solar", "desc": "Ngày Chủ tịch Hồ Chí Minh đọc Tuyên ngôn độc lập."},
    {"name": "Phụ nữ Việt Nam", "day": 20, "month": 10, "type": "solar", "desc": "Ngày thành lập Hội Liên hiệp Phụ nữ Việt Nam."},
    {"name": "Nhà giáo Việt Nam", "day": 20, "month": 11, "type": "solar", "desc": "Ngày tôn vinh nghề giáo."},
    {"name": "Quân đội Nhân dân", "day": 22, "month": 12, "type": "solar", "desc": "Ngày thành lập Quân đội Nhân dân Việt Nam."},
    {"name": "Giáng Sinh", "day": 24, "month": 12, "type": "solar", "desc": "Lễ Thiên Chúa giáng sinh (Noel)."},
    {"name": "Tết Nguyên Đán", "day": 1, "month": 1, "type": "lunar", "desc": "Mùng 1 Tết - Ngày đầu tiên của năm mới Âm lịch."},
    {"name": "Giỗ Tổ Hùng Vương", "day": 10, "month": 3, "type": "lunar", "desc": "Ngày tưởng nhớ các Vua Hùng dựng nước."},
    {"name": "Lễ Phật Đản", "day": 15, "month": 4, "type": "lunar", "desc": "Kỷ niệm ngày sinh của Đức Phật."},
    {"name": "Tết Đoan Ngọ", "day": 5, "month": 5, "type": "lunar", "desc": "Tết giết sâu bọ."},
    {"name": "Lễ Vu Lan", "day": 15, "month": 7, "type": "lunar", "desc": "Ngày xá tội vong nhân và báo hiếu cha mẹ."},
    {"name": "Tết Trung Thu", "day": 15, "month": 8, "type": "lunar", "desc": "Tết thiếu nhi, rước đèn phá cỗ."},
    {"name": "Ông Táo về trời", "day": 23, "month": 12, "type": "lunar", "desc": "Ngày tiễn Táo Quân lên chầu trời."},
  ];

  static Map<String, dynamic> checkHoliday(int solarDay, int solarMonth, int lunarDay, int lunarMonth) {
    for (var h in HOLIDAYS_DATA) {
      if (h['type'] == 'solar' && h['day'] == solarDay && h['month'] == solarMonth) return {"isHoliday": true, "name": h['name']};
      if (h['type'] == 'lunar' && h['day'] == lunarDay && h['month'] == lunarMonth) return {"isHoliday": true, "name": h['name']};
    }
    return {"isHoliday": false, "name": ""};
  }

  static String getSolarTerm(DateTime date) {
    int day = date.day; int month = date.month;
    if (month == 1) return day < 6 ? "Tiểu Hàn" : (day < 21 ? "Tiểu Hàn" : "Đại Hàn");
    if (month == 2) return day < 4 ? "Đại Hàn" : (day < 19 ? "Lập Xuân" : "Vũ Thủy");
    if (month == 3) return day < 6 ? "Vũ Thủy" : (day < 21 ? "Kinh Trập" : "Xuân Phân");
    if (month == 4) return day < 5 ? "Xuân Phân" : (day < 20 ? "Thanh Minh" : "Cốc Vũ");
    if (month == 5) return day < 6 ? "Cốc Vũ" : (day < 21 ? "Lập Hạ" : "Tiểu Mãn");
    if (month == 6) return day < 6 ? "Tiểu Mãn" : (day < 21 ? "Mang Chủng" : "Hạ Chí");
    if (month == 7) return day < 7 ? "Hạ Chí" : (day < 23 ? "Tiểu Thử" : "Đại Thử");
    if (month == 8) return day < 8 ? "Đại Thử" : (day < 23 ? "Lập Thu" : "Xử Thử");
    if (month == 9) return day < 8 ? "Xử Thử" : (day < 23 ? "Bạch Lộ" : "Thu Phân");
    if (month == 10) return day < 8 ? "Thu Phân" : (day < 23 ? "Hàn Lộ" : "Sương Giáng");
    if (month == 11) return day < 7 ? "Sương Giáng" : (day < 22 ? "Lập Đông" : "Tiểu Tuyết");
    if (month == 12) return day < 7 ? "Tiểu Tuyết" : (day < 22 ? "Đại Tuyết" : "Đông Chí");
    return "";
  }

  static String getCanChiHour(String canDay, int hour) {
    int chiIndex = (hour == 23 || hour == 0) ? 0 : ((hour < 23) ? (hour + 1) ~/ 2 : 0);
    int canDayIndex = CAN.indexOf(canDay.split(" ")[0]);
    int currentCanIndex = ((canDayIndex % 5) * 2 + chiIndex) % 10;
    return "${CAN[currentCanIndex]} ${CHI[chiIndex]}";
  }

  static LunarDateModel convertSolarToLunar(DateTime date) {
    List<int> lunarValues = convertSolar2Lunar(date.day, date.month, date.year, 7);
    int day = lunarValues[0]; int month = lunarValues[1]; int year = lunarValues[2]; bool isLeap = lunarValues[3] == 1;
    var holidayInfo = checkHoliday(date.day, date.month, day, month);
    
    int jd = date.day + ((153 * (date.month + 12 * ((14 - date.month) ~/ 12) - 3) + 2) ~/ 5) + 365 * (date.year + 4800 - ((14 - date.month) ~/ 12)) + ((date.year + 4800 - ((14 - date.month) ~/ 12)) ~/ 4) - ((date.year + 4800 - ((14 - date.month) ~/ 12)) ~/ 100) + ((date.year + 4800 - ((14 - date.month) ~/ 12)) ~/ 400) - 32045;
    String canDayRaw = CAN[(jd + 9) % 10]; 
    String canDay = CAN[(jd + 9) % 10]; String chiDay = CHI[(jd + 1) % 12];
    String canMonth = CAN[(year * 12 + month + 3) % 10]; String chiMonth = CHI[(month + 1) % 12];
    String canYear = CAN[(year + 6) % 10]; String chiYear = CHI[(year + 8) % 12];
    
    DateTime now = DateTime.now();
    int currentHour = (date.year == now.year && date.month == now.month && date.day == now.day) ? now.hour : 12; 
    String gioCanChi = getCanChiHour(canDayRaw, currentHour);

    return LunarDateModel(
      day: day, month: month, year: year, isLeap: isLeap,
      canChiDay: "$canDay $chiDay", canChiMonth: "$canMonth $chiMonth", canChiYear: "$canYear $chiYear",
      isHoliday: holidayInfo['isHoliday'], holidayName: holidayInfo['name'],
      tietKhi: getSolarTerm(date), gioCanChi: gioCanChi,
    );
  }

  static String getGioHoangDao(String chiDay) {
    String chi = "";
    for (var c in CHI) {
      if (chiDay.contains(c)) {
        chi = c;
        break;
      }
    }
    switch (chi) {
      case "Dần":
      case "Thân":
        return "Tý (23-1), Sửu (1-3), Thìn (7-9), Tỵ (9-11), Mùi (13-15), Tuất (19-21)";
      case "Mão":
      case "Dậu":
        return "Tý (23-1), Dần (3-5), Mão (5-7), Ngọ (11-13), Mùi (13-15), Dậu (17-19)";
      case "Thìn":
      case "Tuất":
        return "Dần (3-5), Thìn (7-9), Tỵ (9-11), Thân (15-17), Dậu (17-19), Hợi (21-23)";
      case "Tỵ":
      case "Hợi":
        return "Sửu (1-3), Thìn (7-9), Ngọ (11-13), Mùi (13-15), Tuất (19-21), Hợi (21-23)";
      case "Tý":
      case "Ngọ":
        return "Tý (23-1), Sửu (1-3), Mão (5-7), Ngọ (11-13), Thân (15-17), Dậu (17-19)";
      case "Sửu":
      case "Mùi":
        return "Dần (3-5), Mão (5-7), Tỵ (9-11), Thân (15-17), Tuất (19-21), Hợi (21-23)";
      default:
        return "Đang cập nhật...";
    }
  }

  static Map<String, String> getLoiKhuyen(int lunarMonth, String canChiDay) {
    int dayChiIndex = 0;
    for (int i = 0; i < CHI.length; i++) {
      if (canChiDay.contains(CHI[i])) {
        dayChiIndex = i;
        break;
      }
    }
    int monthBaseChiIndex = (lunarMonth + 1) % 12;
    int trucIndex = (dayChiIndex - monthBaseChiIndex + 12) % 12;
    return THAP_NHI_TRUC[trucIndex];
  }
}

class AppStyles {
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    begin: Alignment.topLeft, end: Alignment.bottomRight
  );
  
  static const double fabSize = 55.0; 
  static const double fabBottomPos = 110.0;
  static const double cornerRadius = 24.0; 
}

Future<T?> showGlassDialog<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: "", 
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      var curve = Curves.easeOutCubic;
      var slideTween = Tween(begin: const Offset(0.0, 0.1), end: Offset.zero).chain(CurveTween(curve: curve));
      var fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(slideTween),
        child: FadeTransition(
          opacity: animation.drive(fadeTween),
          child: child,
        ),
      );
    },
  );
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
  int _themeStrategy = 0; 
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
      _scheduleStart = TimeOfDay(hour: prefs.getInt('themeStartH') ?? 18, minute: prefs.getInt('themeStartM') ?? 0);
      _scheduleEnd = TimeOfDay(hour: prefs.getInt('themeEndH') ?? 6, minute: prefs.getInt('themeEndM') ?? 0);
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
    if (_themeStrategy == 1) return _isDarkManual ? ThemeMode.dark : ThemeMode.light;
    
    final now = TimeOfDay.now();
    final double nowMin = now.hour * 60.0 + now.minute;
    final double startMin = _scheduleStart.hour * 60.0 + _scheduleStart.minute;
    final double endMin = _scheduleEnd.hour * 60.0 + _scheduleEnd.minute;

    if (startMin < endMin) {
      return (nowMin >= startMin && nowMin < endMin) ? ThemeMode.dark : ThemeMode.light;
    } else {
      return (nowMin >= startMin || nowMin < endMin) ? ThemeMode.dark : ThemeMode.light;
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.light),
        textTheme: Typography.material2021(platform: TargetPlatform.android).black.apply(fontFamily: 'Roboto'),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        primaryColor: const Color(0xFF6DD5FA),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark),
        textTheme: Typography.material2021(platform: TargetPlatform.android).white.apply(fontFamily: 'Roboto'),
        useMaterial3: true,
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
    required this.themeStrategy, required this.isDarkManual,
    required this.scheduleStart, required this.scheduleEnd,
    required this.onStrategyChanged, required this.onManualChanged, required this.onScheduleChanged,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController; 

  final List<String> _titles = ["Lịch Vạn Niên", "Việc Cần Làm", "Tìm Kiếm", "Cài Đặt"];
  
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
    _pageController = PageController();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
      setState(() => _startingDayOfWeek = StartingDayOfWeek.values[startDayIndex]);
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

  // --- CẬP NHẬT: THÊM TÁC VỤ VỚI KHOẢNG THỜI GIAN ---
  void _addTask(String title, DateTime startTime, DateTime endTime, String tag, int reminderMinutes) {
    setState(() {
      _tasks.add(TodoTask(
        id: DateTime.now().toString(), 
        title: title, 
        startTime: startTime, 
        endTime: endTime,
        tag: tag,
        reminderMinutes: reminderMinutes
      ));
    });
    _saveTasks();
    _scheduleNotification(title, startTime, reminderMinutes);
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

  // --- LOGIC NHẮC NHỞ ---
  Future<void> _scheduleNotification(String body, DateTime startTime, int reminderMinutes) async {
    final DateTime scheduledTime = startTime.subtract(Duration(minutes: reminderMinutes));
    
    if (scheduledTime.isAfter(DateTime.now())) {
       const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'task_channel', 'Nhắc nhở công việc',
        importance: Importance.max, priority: Priority.high,
      );
      const NotificationDetails details = NotificationDetails(android: androidDetails);
      await flutterLocalNotificationsPlugin.show(0, 'Sắp đến hạn: $body', 'Vào lúc: ${DateFormat('HH:mm').format(startTime)}', details);
    }
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

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  void _onBottomNavTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutQuad,
    );
  }

  // --- HIỂN THỊ CHI TIẾT TASK (CÓ KHOẢNG THỜI GIAN) ---
  void _showTaskDetail(TodoTask task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color tagColor = TaskTags.tags[task.tag] ?? Colors.grey;
    IconData tagIcon = TaskTags.icons[task.tag] ?? Icons.label;

    showGlassDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(), 
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {}, 
                child: GlassContainer(
                  width: 340, height: null, borderRadius: 24, opacity: isDark ? 0.2 : 0.95,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: tagColor.withOpacity(0.2), shape: BoxShape.circle),
                              child: Icon(tagIcon, color: tagColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(task.tag, style: TextStyle(color: tagColor, fontWeight: FontWeight.bold, fontSize: 16))),
                            GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54))
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(task.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87, decoration: task.isDone ? TextDecoration.lineThrough : null)),
                        const SizedBox(height: 16),
                        
                        // HIỂN THỊ KHOẢNG THỜI GIAN
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.access_time_filled, size: 18, color: isDark ? Colors.white54 : Colors.black54),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Từ: ${DateFormat('HH:mm - dd/MM/yyyy').format(task.startTime)}", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87)),
                                const SizedBox(height: 4),
                                Text("Đến: ${DateFormat('HH:mm - dd/MM/yyyy').format(task.endTime)}", style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87)),
                              ],
                            ),
                          ),
                        ]),
                        
                        const SizedBox(height: 12),
                        if (task.reminderMinutes > 0)
                          Row(children: [Icon(Icons.alarm, size: 18, color: Colors.orangeAccent), const SizedBox(width: 8), Text("Nhắc trước ${task.reminderMinutes >= 60 ? '${task.reminderMinutes ~/ 60} giờ' : '${task.reminderMinutes} phút'}", style: TextStyle(fontSize: 14, color: Colors.orangeAccent, fontWeight: FontWeight.w600))]),

                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: BouncingButton(onTap: () { _toggleTask(task.id); Navigator.pop(context); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: task.isDone ? Colors.orangeAccent.withOpacity(0.2) : Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: task.isDone ? Colors.orangeAccent : Colors.green)), child: Center(child: Text(task.isDone ? "Đánh dấu chưa xong" : "Hoàn thành", style: TextStyle(color: task.isDone ? Colors.orangeAccent : Colors.green, fontWeight: FontWeight.bold)))))),
                            const SizedBox(width: 12),
                            BouncingButton(onTap: () { _deleteTask(task.id); Navigator.pop(context); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent)), child: Icon(Icons.delete_outline, color: Colors.redAccent)))
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  // --- TRUNG TÂM THÔNG BÁO ---
  void _showNotificationCenter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final upcomingTasks = _tasks.where((t) => !t.isDone && t.startTime.isAfter(now)).toList();
    upcomingTasks.sort((a, b) => a.startTime.compareTo(b.startTime));
    final completedTasks = _tasks.where((t) => t.isDone).toList();
    final overdueTasks = _tasks.where((t) => !t.isDone && t.startTime.isBefore(now)).toList();

    showGlassDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: GlassContainer(
            width: double.infinity, 
            height: MediaQuery.of(context).size.height * 0.7, 
            borderRadius: 24, opacity: isDark ? 0.2 : 0.95,
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Thông báo", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)), GestureDetector(onTap: ()=>Navigator.pop(context), child: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black54))])),
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if(overdueTasks.isNotEmpty) ...[Text("Quá hạn", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10), ...overdueTasks.map((t) => _buildNotiItem(t, isDark, Colors.redAccent)), const SizedBox(height: 20)],
                        Text("Sắp tới", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10),
                        if (upcomingTasks.isEmpty) Text("Không có công việc sắp tới", style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontStyle: FontStyle.italic)),
                        ...upcomingTasks.map((t) => _buildNotiItem(t, isDark, Colors.blueAccent)),
                        const SizedBox(height: 20),
                        Text("Đã hoàn thành", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10),
                        if (completedTasks.isEmpty) Text("Chưa có công việc hoàn thành", style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontStyle: FontStyle.italic)),
                        ...completedTasks.map((t) => _buildNotiItem(t, isDark, Colors.green)),
                        const SizedBox(height: 20),
                      ])))
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildNotiItem(TodoTask task, bool isDark, Color accentColor) {
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: accentColor.withOpacity(0.3))), child: Row(children: [Icon(TaskTags.icons[task.tag], color: accentColor, size: 24), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task.title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, decoration: task.isDone ? TextDecoration.lineThrough : null)), const SizedBox(height: 4), Text("${DateFormat('HH:mm dd/MM').format(task.startTime)} ➔ ${DateFormat('HH:mm').format(task.endTime)}", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12))])), if (task.reminderMinutes > 0 && !task.isDone) Icon(Icons.alarm, size: 16, color: isDark ? Colors.white38 : Colors.black38)]));
  }

  // --- DIALOG THÊM VIỆC (MỚI: TỪ NGÀY -> ĐẾN NGÀY) ---
  void _showAddTaskDialog() {
    final TextEditingController controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Khởi tạo thời gian mặc định
    DateTime startDateTime = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, DateTime.now().hour, DateTime.now().minute);
    DateTime endDateTime = startDateTime.add(const Duration(hours: 1)); // Mặc định +1 giờ
    
    String selectedTag = "Lời nhắc"; 
    int selectedReminder = 0; 

    final Map<int, String> reminderOptions = {0: "Không", 5: "5 phút", 10: "10 phút", 30: "30 phút", 60: "1 giờ", 1440: "1 ngày"};

    showGlassDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { FocusScope.of(context).unfocus(); Navigator.of(context).pop(); },
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, 
                    child: GlassContainer(
                      width: 340, height: null, borderRadius: 24, opacity: isDark ? 0.2 : 0.95,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Thêm công việc", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: controller,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
                              maxLines: 3, minLines: 1, 
                              decoration: InputDecoration(hintText: "Nhập nội dung...", hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                            ),
                            const SizedBox(height: 16),
                            
                            // CHỌN TAG
                            Text("Loại công việc:", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: TaskTags.tags.entries.map((entry) { bool isSelected = selectedTag == entry.key; return GestureDetector(onTap: () => setStateDialog(() => selectedTag = entry.key), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isSelected ? entry.value : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? entry.value : (isDark ? Colors.white24 : Colors.black12))), child: Text(entry.key, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)))); }).toList())),
                            
                            const SizedBox(height: 16),
                            
                            // CHỌN THỜI GIAN (TỪ - ĐẾN)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Bắt đầu:", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      _buildDateTimeButton(context, startDateTime, isDark, (picked) {
                                        setStateDialog(() {
                                          startDateTime = picked;
                                          // Tự động đẩy giờ kết thúc nếu bắt đầu trễ hơn
                                          if (endDateTime.isBefore(startDateTime)) {
                                            endDateTime = startDateTime.add(const Duration(hours: 1));
                                          }
                                        });
                                      }),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Kết thúc:", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      _buildDateTimeButton(context, endDateTime, isDark, (picked) {
                                        setStateDialog(() {
                                          endDateTime = picked;
                                          // Kiểm tra nếu kết thúc sớm hơn bắt đầu
                                          if (endDateTime.isBefore(startDateTime)) {
                                            startDateTime = endDateTime.subtract(const Duration(hours: 1));
                                          }
                                        });
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            Text("Nhắc trước:", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: reminderOptions.entries.map((entry) { bool isSelected = selectedReminder == entry.key; return GestureDetector(onTap: () => setStateDialog(() => selectedReminder = entry.key), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isSelected ? Colors.orangeAccent : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.orangeAccent : (isDark ? Colors.white24 : Colors.black12))), child: Text(entry.value, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)))); }).toList())),

                            const SizedBox(height: 24),
                            SizedBox(width: double.infinity, height: 48, child: BouncingButton(onTap: () { if (controller.text.isNotEmpty) { _addTask(controller.text, startDateTime, endDateTime, selectedTag, selectedReminder); Navigator.pop(context); } }, child: Container(decoration: BoxDecoration(gradient: AppStyles.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF4FACFE).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]), alignment: Alignment.center, child: const Text("Lưu công việc", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))))
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  // Helper cho nút chọn ngày giờ
  Widget _buildDateTimeButton(BuildContext context, DateTime current, bool isDark, Function(DateTime) onPicked) {
    return BouncingButton(
      onTap: () {
        showGlassDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            DateTime temp = current;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(ctx),
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: GestureDetector(
                    onTap: (){},
                    child: GlassContainer(
                      width: 320, height: 350, borderRadius: 24, opacity: isDark ? 0.2 : 0.95,
                      child: Column(children: [
                        Padding(padding: const EdgeInsets.all(16), child: Text("Chọn thời gian", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
                        Expanded(child: CupertinoTheme(data: CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light), child: CupertinoDatePicker(mode: CupertinoDatePickerMode.dateAndTime, initialDateTime: current, use24hFormat: true, onDateTimeChanged: (val) { temp = val; }))),
                        Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: BouncingButton(onTap: () { onPicked(temp); Navigator.pop(ctx); }, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(gradient: AppStyles.primaryGradient, borderRadius: BorderRadius.circular(12)), child: const Text("Xác nhận", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))))
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('HH:mm').format(current), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(DateFormat('dd/MM').format(current), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isToday = isSameDay(_selectedDay, DateTime.now());
    
    double screenWidth = MediaQuery.of(context).size.width;
    double bottomBarWidth = screenWidth > 600 ? 400 : screenWidth - 40; 

    final List<Widget> screens = [
      CalendarContent(
        focusedDay: _focusedDay, selectedDay: _selectedDay,
        onDaySelected: _onDaySelected, startingDayOfWeek: _startingDayOfWeek,
        tasks: _tasks, onDeleteTask: _deleteTask, onToggleTask: _toggleTask,
        onTaskTap: _showTaskDetail, 
      ),
      TodoContent(
        tasks: _tasks, 
        onDelete: _deleteTask, 
        onToggle: _toggleTask, 
        onAddTask: _showAddTaskDialog,
        onTaskTap: _showTaskDetail, 
      ), 
      SearchContent(tasks: _tasks, onTaskTap: _showTaskDetail), 
      SettingsContent(
        themeStrategy: widget.themeStrategy,
        isDarkManual: widget.isDarkManual,
        scheduleStart: widget.scheduleStart,
        scheduleEnd: widget.scheduleEnd,
        onStrategyChanged: widget.onStrategyChanged,
        onManualChanged: widget.onManualChanged,
        onScheduleChanged: widget.onScheduleChanged,
        currentStartDay: _startingDayOfWeek,
        onStartDayChanged: (day) { setState(() => _startingDayOfWeek = day); _saveSettings(); },
        notifyFullMoon: _notifyFullMoon, notifyHoliday: _notifyHoliday, reminderTime: _reminderTime,
        onToggleFullMoon: (val) { setState(() => _notifyFullMoon = val); _saveSettings(); },
        onToggleHoliday: (val) { setState(() => _notifyHoliday = val); _saveSettings(); },
        onReminderTimeChanged: (time) { setState(() => _reminderTime = time); _saveSettings(); },
      ),
    ];

    final bgGradient = isDark 
      ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)])
      : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFE6E9F0)]);

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // FLOATING HEADER
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_titles[_selectedIndex], style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
                          Container(margin: const EdgeInsets.only(top: 6), height: 5, width: 40, decoration: BoxDecoration(gradient: AppStyles.primaryGradient, borderRadius: BorderRadius.circular(2.5)))
                        ],
                      ),
                      const Spacer(),
                      // --- NÚT THÔNG BÁO ---
                      BouncingButton(
                        onTap: _showNotificationCenter, 
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                            shape: BoxShape.circle
                          ),
                          child: Icon(Icons.notifications_none_rounded, color: isDark ? Colors.white : Colors.black87, size: 26)
                        )
                      )
                    ],
                  ),
                ),
              ),
            ),
            
            // CONTENT WITH SWIPE (PAGEVIEW)
            Positioned.fill(
              top: 100, bottom: 0, 
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: screens,
              ),
            ),

            if ((_selectedIndex == 0 && !isToday) || _selectedIndex == 1)
              Positioned(
                bottom: AppStyles.fabBottomPos, right: 25,
                child: BouncingButton(
                  onTap: _selectedIndex == 0 ? _goToday : _showAddTaskDialog,
                  child: Container(
                    width: AppStyles.fabSize, height: AppStyles.fabSize, 
                    decoration: BoxDecoration(gradient: AppStyles.primaryGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF4FACFE).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Center(child: _selectedIndex == 0 ? Text("${DateTime.now().day}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)) : Icon(Icons.add, color: Colors.white, size: 28)),
                  ),
                ),
              ),

            // FLOATING BOTTOM NAVIGATION BAR
            Positioned(
              bottom: 30,
              child: SafeArea(
                child: GlassContainer(
                  width: bottomBarWidth, height: 70, borderRadius: 35, blur: 20, opacity: isDark ? 0.2 : 0.8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(Icons.calendar_month_rounded, 0, isDark),
                      _buildNavItem(Icons.check_circle_outline_rounded, 1, isDark),
                      _buildNavItem(Icons.search_rounded, 2, isDark),
                      _buildNavItem(Icons.settings_rounded, 3, isDark),
                    ],
                  ),
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
    return BouncingButton(
      onTap: () => _onBottomNavTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isSelected ? (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.05)) : Colors.transparent, shape: BoxShape.circle),
        child: Icon(icon, color: isSelected ? activeColor : inactiveColor, size: 26),
      ),
    );
  }
}

// ==========================================
// 4. CALENDAR CONTENT
// ==========================================

class CalendarContent extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final StartingDayOfWeek startingDayOfWeek;
  final List<TodoTask> tasks; 
  final Function(String) onDeleteTask;
  final Function(String) onToggleTask;
  final Function(TodoTask) onTaskTap; 

  const CalendarContent({
    super.key, 
    required this.focusedDay, required this.selectedDay, 
    required this.onDaySelected, required this.startingDayOfWeek,
    required this.tasks, required this.onDeleteTask, required this.onToggleTask, 
    required this.onTaskTap,
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
      _loiKhuyen = LunarUtils.getLoiKhuyen(_lunarDate.month, _lunarDate.canChiDay);
      _gioHoangDao = LunarUtils.getGioHoangDao(_lunarDate.canChiDay);
    });
  }

  // Hiển thị công việc có ngày bắt đầu trùng với ngày đang chọn
  List<TodoTask> _getTasksForDay(DateTime day) {
    return widget.tasks.where((task) => isSameDay(task.startTime, day)).toList();
  }

  // --- SHOW MONTH YEAR PICKER (BOUNCY) ---
  void _showMonthYearPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showGlassDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        int tempYear = widget.focusedDay.year;
        int tempMonth = widget.focusedDay.month;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: (){},
                child: GlassContainer(
                  width: 320, height: 350, borderRadius: 24, opacity: isDark ? 0.2 : 0.95,
                  child: Column(
                    children: [
                      Padding(padding: const EdgeInsets.all(16), child: Text("Chọn Tháng & Năm", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
                      Expanded(child: Row(children: [Expanded(child: CupertinoPicker(itemExtent: 40, scrollController: FixedExtentScrollController(initialItem: tempYear - 2000), onSelectedItemChanged: (int index) { tempYear = 2000 + index; }, children: List.generate(100, (index) => Center(child: Text("${2000 + index}", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18)))))), Expanded(child: CupertinoPicker(itemExtent: 40, scrollController: FixedExtentScrollController(initialItem: tempMonth - 1), onSelectedItemChanged: (int index) { tempMonth = index + 1; }, children: List.generate(12, (index) => Center(child: Text("Tháng ${index + 1}", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18))))))])),
                      Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 48, child: Container(decoration: BoxDecoration(gradient: AppStyles.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF4FACFE).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () { final newDate = DateTime(tempYear, tempMonth, 1); widget.onDaySelected(newDate, newDate); Navigator.pop(context); }, child: const Text("Xác nhận", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))))))
                    ],
                  ),
                ),
              ),
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
        padding: const EdgeInsets.only(bottom: 120), 
        child: Column(
          children: [
            GlassContainer(
              width: MediaQuery.of(context).size.width * 0.9, borderRadius: AppStyles.cornerRadius, opacity: isDark ? 0.1 : 0.7,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
                child: TableCalendar(
                  firstDay: DateTime.utc(2000, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: widget.focusedDay,
                  selectedDayPredicate: (day) => isSameDay(widget.selectedDay, day),
                  onDaySelected: widget.onDaySelected,
                  locale: 'vi_VN',
                  startingDayOfWeek: widget.startingDayOfWeek,
                  rowHeight: 62, daysOfWeekHeight: 45,
                  eventLoader: (day) => _getTasksForDay(day),
                  onHeaderTapped: (focusedDay) => _showMonthYearPicker(context),
                  headerStyle: HeaderStyle(
                    titleCentered: true, formatButtonVisible: false,
                    titleTextFormatter: (date, locale) => "Tháng ${date.month} / ${date.year}",
                    titleTextStyle: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.5),
                    leftChevronIcon: _buildChevron(isDark, Icons.chevron_left_rounded, textColor),
                    rightChevronIcon: _buildChevron(isDark, Icons.chevron_right_rounded, textColor),
                    headerPadding: const EdgeInsets.only(bottom: 20),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    dowTextFormatter: (date, locale) => DateFormat.E(locale).format(date)[0].toUpperCase() + DateFormat.E(locale).format(date).substring(1),
                    weekdayStyle: TextStyle(color: subColor, fontWeight: FontWeight.w700, fontSize: 13),
                    weekendStyle: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) => _buildCustomDayCell(day, isDark, false),
                    selectedBuilder: (context, day, focusedDay) => _buildCustomDayCell(day, isDark, true),
                    todayBuilder: (context, day, focusedDay) => _buildCustomDayCell(day, isDark, false, isToday: true),
                    outsideBuilder: (context, day, focusedDay) => Opacity(opacity: 0.2, child: _buildCustomDayCell(day, isDark, false)),
                    markerBuilder: (context, day, events) {
                      final hasTask = widget.tasks.any((t) => isSameDay(t.startTime, day));
                      if (events.isEmpty && !hasTask) return null;
                      return Positioned(
                        bottom: 5,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasTask) Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
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
              width: MediaQuery.of(context).size.width * 0.9, borderRadius: AppStyles.cornerRadius, opacity: isDark ? 0.1 : 0.7,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (_lunarDate.isHoliday)
                      Container(
                        margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.celebration, color: Colors.redAccent, size: 18), const SizedBox(width: 8),
                            Text(_lunarDate.holidayName.toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                      ),
                    
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text("ÂM LỊCH", style: TextStyle(color: subColor, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)), const SizedBox(height: 4),
                            Text("${_lunarDate.day}", style: TextStyle(fontSize: 56, fontWeight: FontWeight.w300, color: textColor, height: 1.0)),
                            if (_lunarDate.isLeap) Text("(Nhuận)", style: TextStyle(color: subColor, fontSize: 12)),
                        ]),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            _buildTag(isDark, _lunarDate.canChiDay), const SizedBox(height: 8),
                            Text("Tháng ${_lunarDate.month} · ${_lunarDate.canChiMonth}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                            Text("Năm ${_lunarDate.canChiYear}", style: TextStyle(fontSize: 14, color: subColor)),
                            const SizedBox(height: 8),
                            if (_lunarDate.tietKhi.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text("Tiết ${_lunarDate.tietKhi}", style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)))
                        ]),
                    ]),
                    const SizedBox(height: 20),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(16)), child: Column(children: [
                          Row(children: [Icon(Icons.access_time_filled, color: Colors.blueAccent, size: 18), const SizedBox(width: 8), Text("Giờ hiện tại: ", style: TextStyle(fontSize: 12, color: subColor)), Text(_lunarDate.gioCanChi, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor))]),
                          const Divider(height: 16, color: Colors.white10),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.stars_rounded, color: Colors.amber[400], size: 18), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Giờ Hoàng Đạo", style: TextStyle(fontSize: 11, color: subColor)), Text(_gioHoangDao, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor))]))]),
                    ])),
                    const SizedBox(height: 20),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _buildDosDontsBox(true, _loiKhuyen['tot']!, isDark)), 
                      const SizedBox(width: 12), 
                      Expanded(child: _buildDosDontsBox(false, _loiKhuyen['xau']!, isDark))
                    ]),
                    
                    const SizedBox(height: 25),
                    Align(alignment: Alignment.centerLeft, child: Row(children: [Icon(Icons.check_circle_outline, size: 16, color: subColor), const SizedBox(width: 8), Text("Công việc hôm nay", style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.bold))])),
                    const SizedBox(height: 10),
                    if (selectedDayTasks.isEmpty)
                       Padding(padding: const EdgeInsets.all(10), child: Text("Chưa có công việc nào", style: TextStyle(color: subColor, fontSize: 12, fontStyle: FontStyle.italic)))
                    else
                       ...selectedDayTasks.map((task) => Container(
                         margin: const EdgeInsets.only(bottom: 8),
                         child: ListTile(
                           dense: true,
                           contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                           onTap: () => widget.onTaskTap(task),
                           leading: GestureDetector(
                             onTap: () => widget.onToggleTask(task.id),
                             child: Icon(task.isDone ? Icons.check_circle : Icons.circle_outlined, color: task.isDone ? Colors.green : subColor, size: 20),
                           ),
                           title: Text(task.title, style: TextStyle(decoration: task.isDone ? TextDecoration.lineThrough : null, color: textColor, fontSize: 14)),
                           subtitle: Row(
                             children: [
                               Icon(Icons.access_time, size: 12, color: subColor),
                               const SizedBox(width: 4),
                               Text("${DateFormat('HH:mm').format(task.startTime)} - ${DateFormat('HH:mm').format(task.endTime)}", style: TextStyle(color: subColor, fontSize: 12)),
                               const SizedBox(width: 8),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                 decoration: BoxDecoration(color: (TaskTags.tags[task.tag] ?? Colors.grey).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                 child: Text(task.tag, style: TextStyle(fontSize: 10, color: TaskTags.tags[task.tag] ?? Colors.grey, fontWeight: FontWeight.bold)),
                               )
                             ],
                           ),
                           trailing: GestureDetector(
                             onTap: () => widget.onDeleteTask(task.id),
                             child: Icon(Icons.close, size: 16, color: subColor),
                           ),
                         ),
                       )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChevron(bool isDark, IconData icon, Color color) {
    return Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20));
  }

  Widget _buildCustomDayCell(DateTime date, bool isDark, bool isSelected, {bool isToday = false}) {
    final lunarInfo = LunarUtils.convertSolarToLunar(date);
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final isHoliday = lunarInfo.isHoliday;
    
    Color dayColor = isDark ? Colors.white : Colors.black87;
    Color lunarColor = isDark ? Colors.white38 : Colors.black45;
    
    if (isHoliday) { dayColor = Colors.redAccent; } 
    else if (isWeekend) { dayColor = const Color(0xFFFF6B6B); }
    
    if (isSelected) { dayColor = Colors.white; lunarColor = Colors.white70; }

    return Center(child: Container(width: 48, height: 48, alignment: Alignment.center, decoration: isSelected ? BoxDecoration(gradient: AppStyles.primaryGradient, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: const Color(0xFF4FACFE).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]) : isToday ? BoxDecoration(border: Border.all(color: Colors.blueAccent.withOpacity(0.6), width: 1.5), borderRadius: BorderRadius.circular(14), color: Colors.blueAccent.withOpacity(0.05)) : null, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${date.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: dayColor)), const SizedBox(height: 2), Text('${lunarInfo.day}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: lunarColor))])));
  }

  Widget _buildTag(bool isDark, String text) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white24 : Colors.black12)), child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)));
  }

  Widget _buildDosDontsBox(bool isGood, String text, bool isDark) {
    final colorBase = isGood ? (isDark ? Colors.greenAccent : Colors.green.shade700) : (isDark ? Colors.redAccent : Colors.red.shade700);
    final bgOpacity = isDark ? 0.15 : 0.1;
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colorBase.withOpacity(bgOpacity), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorBase.withOpacity(0.3), width: 1)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(isGood ? Icons.thumb_up_rounded : Icons.thumb_down_rounded, size: 16, color: colorBase), const SizedBox(width: 8), Text(isGood ? "Nên" : "Kỵ", style: TextStyle(color: colorBase, fontWeight: FontWeight.bold, fontSize: 14))]), const SizedBox(height: 8), Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: colorBase.withOpacity(0.9), fontWeight: FontWeight.w600))]));
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
  final Function(TodoTask) onTaskTap; 

  const TodoContent({super.key, required this.tasks, required this.onDelete, required this.onToggle, required this.onAddTask, required this.onTaskTap});
  @override
  State<TodoContent> createState() => TodoContentState();
}
class TodoContentState extends State<TodoContent> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
            GlassContainer(width: double.infinity, height: 60, borderRadius: AppStyles.cornerRadius, opacity: isDark ? 0.1 : 0.7, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Danh sách việc", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)), Text("${widget.tasks.where((t) => t.isDone).length}/${widget.tasks.length}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent))]))), const SizedBox(height: 15),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: widget.tasks.length, 
              itemBuilder: (context, index) { 
                final task = widget.tasks[index]; 
                return Dismissible(
                  key: Key(task.id), direction: DismissDirection.endToStart, onDismissed: (direction) => widget.onDelete(task.id), 
                  background: Container(margin: const EdgeInsets.only(bottom: 12), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.delete_outline, color: Colors.white)), 
                  child: Container(margin: const EdgeInsets.only(bottom: 12), child: GlassContainer(width: double.infinity, borderRadius: 16, opacity: isDark ? 0.1 : 0.7, child: ListTile(
                    onTap: () => widget.onTaskTap(task), 
                    leading: GestureDetector(onTap: () => widget.onToggle(task.id), child: Container(width: 24, height: 24, decoration: BoxDecoration(color: task.isDone ? Colors.blueAccent : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: task.isDone ? Colors.blueAccent : (isDark ? Colors.white54 : Colors.black38), width: 2)), child: task.isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null)), 
                    title: Text(task.title, style: TextStyle(decoration: task.isDone ? TextDecoration.lineThrough : null, color: isDark ? (task.isDone ? Colors.white38 : Colors.white) : (task.isDone ? Colors.black38 : Colors.black87))), 
                    subtitle: Row(children: [
                      Icon(Icons.calendar_today, size: 12, color: isDark ? Colors.white30 : Colors.black38), const SizedBox(width: 4), Text(DateFormat('HH:mm dd/MM').format(task.startTime), style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.black38)),
                      const SizedBox(width: 8),
                      Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(color: (TaskTags.tags[task.tag] ?? Colors.grey).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                         child: Text(task.tag, style: TextStyle(fontSize: 10, color: TaskTags.tags[task.tag] ?? Colors.grey, fontWeight: FontWeight.bold)),
                       )
                    ]),
                  )))
                );
              }))
        ]))
    ]);
  }
}

// ==========================================
// 6. SEARCH CONTENT
// ==========================================
class SearchContent extends StatefulWidget {
  final List<TodoTask> tasks; 
  final Function(TodoTask) onTaskTap; 
  const SearchContent({super.key, required this.tasks, required this.onTaskTap});
  @override
  State<SearchContent> createState() => _SearchContentState();
}
class _SearchContentState extends State<SearchContent> {
  String _keyword = "";
  final TextEditingController _controller = TextEditingController();
  
  List<dynamic> get _filteredResults {
    if (_keyword.isEmpty) return [];
    final holidays = LunarUtils.HOLIDAYS_DATA.where((h) => h['name'].toLowerCase().contains(_keyword.toLowerCase())).toList();
    final todos = widget.tasks.where((t) => t.title.toLowerCase().contains(_keyword.toLowerCase())).toList();
    return [...holidays, ...todos];
  }
  
  void _showHolidayDetail(BuildContext context, Map<String, dynamic> holiday) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3436);
    final subColor = isDark ? Colors.white60 : const Color(0xFF636E72);
    final randomAdvice = LunarUtils.THAP_NHI_TRUC[0];

    showGlassDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: GlassContainer(
          width: double.infinity, height: null, borderRadius: 24, opacity: isDark ? 0.2 : 0.95,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.celebration, color: Colors.redAccent, size: 40)), const SizedBox(height: 16),
                Text(holiday['name'], textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.5)), const SizedBox(height: 24),
                Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 30), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)), child: Column(children: [Text("${holiday['day']}", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.blueAccent, height: 1.0)), Text("Tháng ${holiday['month']}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textColor)), const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: holiday['type'] == 'lunar' ? Colors.orangeAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text(holiday['type'] == 'lunar' ? "Lịch Âm" : "Lịch Dương", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: holiday['type'] == 'lunar' ? Colors.orangeAccent : Colors.blueAccent)))])), const SizedBox(height: 24),
                Align(alignment: Alignment.centerLeft, child: Text("Thông tin chi tiết", style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.bold))), const SizedBox(height: 8),
                Text(holiday['desc'] ?? "Đang cập nhật...", style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14, height: 1.5), textAlign: TextAlign.justify), const SizedBox(height: 24),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _buildDetailDosDontsBox(true, randomAdvice['tot']!, isDark)), 
                  const SizedBox(width: 12), 
                  Expanded(child: _buildDetailDosDontsBox(false, randomAdvice['xau']!, isDark))
                ]), 
                const SizedBox(height: 30),
                SizedBox(width: double.infinity, child: BouncingButton(onTap: () => Navigator.pop(context), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: AppStyles.primaryGradient, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF4FACFE).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))]), child: Text("Đóng", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailDosDontsBox(bool isGood, String text, bool isDark) {
    final colorBase = isGood 
        ? (isDark ? Colors.greenAccent : Colors.green.shade700) 
        : (isDark ? Colors.redAccent : Colors.red.shade700);
    final bgOpacity = isDark ? 0.15 : 0.1;

    return Container(
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(color: colorBase.withOpacity(bgOpacity), borderRadius: BorderRadius.circular(16), border: Border.all(color: colorBase.withOpacity(0.2), width: 1)), 
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(isGood ? Icons.thumb_up_rounded : Icons.thumb_down_rounded, size: 14, color: colorBase), const SizedBox(width: 6), Text(isGood ? "Nên" : "Kỵ", style: TextStyle(color: colorBase, fontWeight: FontWeight.bold, fontSize: 13))]), 
        const SizedBox(height: 6), 
        Text(text, style: TextStyle(fontSize: 12, height: 1.3, color: colorBase.withOpacity(0.9), fontWeight: FontWeight.w500))
      ])
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
        GlassContainer(width: double.infinity, height: 60, borderRadius: 16, opacity: isDark ? 0.1 : 0.7, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Row(children: [Icon(Icons.search, color: isDark ? Colors.white54 : Colors.black45), const SizedBox(width: 10), Expanded(child: TextField(controller: _controller, onChanged: (val) => setState(() => _keyword = val), style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(hintText: "Tìm ngày lễ hoặc công việc...", hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38), border: InputBorder.none))), if (_keyword.isNotEmpty) GestureDetector(onTap: () { _controller.clear(); setState(() => _keyword = ""); }, child: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black45, size: 20))]))), const SizedBox(height: 20),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 120),
          itemCount: _filteredResults.length, 
          itemBuilder: (context, index) { 
            final item = _filteredResults[index]; 
            final isHoliday = item is Map<String, dynamic>;
            if (isHoliday) {
                final isLunar = item['type'] == 'lunar';
                return GestureDetector(onTap: () => _showHolidayDetail(context, item), child: Container(margin: const EdgeInsets.only(bottom: 12), child: GlassContainer(width: double.infinity, borderRadius: 16, opacity: isDark ? 0.1 : 0.7, child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isLunar ? Colors.orangeAccent.withOpacity(0.1) : Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: Icon(isLunar ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined, color: isLunar ? Colors.orangeAccent : Colors.blueAccent, size: 24)), title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 16)), subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text("Ngày ${item['day']}/${item['month']}", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13))), trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26)))));
            } else {
                final task = item as TodoTask;
                return Container(margin: const EdgeInsets.only(bottom: 12), child: GlassContainer(width: double.infinity, borderRadius: 16, opacity: isDark ? 0.1 : 0.7, child: ListTile(
                  onTap: () => widget.onTaskTap(task), 
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), 
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 24)), 
                  title: Text(task.title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 16)), 
                  subtitle: Text(DateFormat('dd/MM - HH:mm').format(task.startTime), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)), 
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26))));
            }
        }))
    ]));
  }
}

// ==========================================
// 7. SETTINGS CONTENT
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
    required this.themeStrategy, required this.isDarkManual,
    required this.scheduleStart, required this.scheduleEnd,
    required this.onStrategyChanged, required this.onManualChanged, required this.onScheduleChanged,
    required this.currentStartDay, required this.onStartDayChanged,
    required this.notifyFullMoon, required this.notifyHoliday,
    required this.onToggleFullMoon, required this.onToggleHoliday,
    required this.reminderTime, required this.onReminderTimeChanged,
  });

  @override
  State<SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<SettingsContent> {

  // --- WIDGET SWITCH DÙNG CHUNG ---
  Widget _buildSwitchItem({
    required String title, 
    required IconData icon, 
    required bool value, 
    required Function(bool) onChanged, 
    required bool isDark
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8), 
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.blueAccent.withOpacity(0.1), 
          shape: BoxShape.circle
        ), 
        child: Icon(icon, color: isDark ? Colors.white : Colors.blueAccent, size: 20)
      ),
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
      trailing: GlassSwitch(value: value, onChanged: onChanged),
    );
  }

  void _showVersionInfo(BuildContext context, bool isDark) {
    showGlassDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          width: 320, height: null, borderRadius: 24, opacity: isDark ? 0.2 : 0.95,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: AppStyles.primaryGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFF4FACFE).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]), child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 40)),
                const SizedBox(height: 16),
                Text("Glass Calendar Pro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 4),
                Text("Phiên bản 1.0.0 (Beta)", style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.black54)),
                const SizedBox(height: 20),
                Text("Ứng dụng Lịch Vạn Niên với giao diện kính mờ hiện đại. Hỗ trợ xem ngày âm dương, ngày lễ, giờ hoàng đạo và quản lý công việc cá nhân.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: BouncingButton(onTap: () => Navigator.pop(ctx), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(gradient: AppStyles.primaryGradient, borderRadius: BorderRadius.circular(16)), child: const Text("Đóng", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
              ],
            ),
          ),
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120), 
      child: Column(
        children: [
          _buildSectionHeader("Giao diện", isDark),
          GlassContainer(
            width: double.infinity, borderRadius: AppStyles.cornerRadius, opacity: isDark ? 0.1 : 0.7,
            child: Column(children: [
              _buildThemeOption(0, "Theo hệ thống (Mặc định)", Icons.settings_system_daydream, isDark),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
              _buildThemeOption(1, "Thủ công (Sáng/Tối)", Icons.tune, isDark),
              if (widget.themeStrategy == 1)
                 _buildSwitchItem(title: "Bật chế độ tối", icon: Icons.dark_mode, value: widget.isDarkManual, onChanged: widget.onManualChanged, isDark: isDark),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
              _buildThemeOption(2, "Theo lịch trình", Icons.schedule, isDark),
              if (widget.themeStrategy == 2)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTimePickerButton("Bắt đầu (Tối)", widget.scheduleStart, (t) => widget.onScheduleChanged(t, widget.scheduleEnd), isDark),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      _buildTimePickerButton("Kết thúc (Sáng)", widget.scheduleEnd, (t) => widget.onScheduleChanged(widget.scheduleStart, t), isDark),
                    ],
                  ),
                ),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
              _buildActionItem(icon: Icons.calendar_today, title: "Tuần bắt đầu vào", subtitle: widget.currentStartDay == StartingDayOfWeek.monday ? "Thứ Hai" : "Chủ Nhật", isDark: isDark, onTap: () {
                showGlassDialog(context: context, barrierDismissible: true, builder: (context) => Dialog(backgroundColor: Colors.transparent, child: GlassContainer(width: 300, height: 180, borderRadius: 20, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ListTile(title: Text("Thứ Hai", style: TextStyle(color: isDark ? Colors.white : Colors.black)), trailing: widget.currentStartDay == StartingDayOfWeek.monday ? const Icon(Icons.check, color: Colors.blueAccent) : null, onTap: () { widget.onStartDayChanged(StartingDayOfWeek.monday); Navigator.pop(context); }),
                  Divider(height: 1, color: isDark ? Colors.white24 : Colors.black12),
                  ListTile(title: Text("Chủ Nhật", style: TextStyle(color: isDark ? Colors.white : Colors.black)), trailing: widget.currentStartDay == StartingDayOfWeek.sunday ? const Icon(Icons.check, color: Colors.blueAccent) : null, onTap: () { widget.onStartDayChanged(StartingDayOfWeek.sunday); Navigator.pop(context); }),
                ]))));
              }),
            ]),
          ),
          const SizedBox(height: 25),

          _buildSectionHeader("Thông báo & Nhắc nhở", isDark),
          GlassContainer(
             width: double.infinity, borderRadius: AppStyles.cornerRadius, opacity: isDark ? 0.1 : 0.7,
            child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.access_time_filled, color: isDark ? Colors.white : Colors.blueAccent, size: 20)), const SizedBox(width: 16), Text("Giờ nhắc nhở", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 16))]),
                      GestureDetector(
                        onTap: () async {
                          showGlassDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) {
                              TimeOfDay tempTime = widget.reminderTime;
                              return Dialog(
                                backgroundColor: Colors.transparent,
                                child: GlassContainer(
                                  width: 320, height: 350, borderRadius: 24, opacity: isDark ? 0.2 : 0.95,
                                  child: Column(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(16), child: Text("Chọn giờ nhắc", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black))),
                                      Expanded(child: CupertinoTheme(data: CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light, textTheme: CupertinoTextThemeData(dateTimePickerTextStyle: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 20))), child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: DateTime(2024, 1, 1, widget.reminderTime.hour, widget.reminderTime.minute), onDateTimeChanged: (val) { tempTime = TimeOfDay(hour: val.hour, minute: val.minute); }, use24hFormat: true))),
                                      Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: BouncingButton(onTap: () { widget.onReminderTimeChanged(tempTime); Navigator.pop(context); }, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(gradient: AppStyles.primaryGradient, borderRadius: BorderRadius.circular(12)), child: const Text("Xác nhận", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))))
                                    ],
                                  ),
                                ),
                              );
                            }
                          );
                        },
                        child: GlassContainer(width: 80, height: 36, borderRadius: 10, opacity: 0.3, child: Center(child: Text("${widget.reminderTime.hour.toString().padLeft(2, '0')}:${widget.reminderTime.minute.toString().padLeft(2, '0')}", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)))),
                      )
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                _buildSwitchItem(title: "Nhắc Rằm / Mùng 1", icon: Icons.notifications_active, value: widget.notifyFullMoon, onChanged: widget.onToggleFullMoon, isDark: isDark),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                _buildSwitchItem(title: "Nhắc ngày lễ tết", icon: Icons.celebration, value: widget.notifyHoliday, onChanged: widget.onToggleHoliday, isDark: isDark),
            ]),
          ),
          
          const SizedBox(height: 25),
          _buildSectionHeader("Khác", isDark),
          GlassContainer(
            width: double.infinity, borderRadius: AppStyles.cornerRadius, opacity: isDark ? 0.1 : 0.7,
            child: Column(children: [
                _buildActionItem(icon: Icons.info_outline, title: "Phiên bản", subtitle: "1.0.0 (Beta)", isDark: isDark, onTap: () => _showVersionInfo(context, isDark)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(int type, String title, IconData icon, bool isDark) {
    final isSelected = widget.themeStrategy == type;
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: isDark ? Colors.white : Colors.blueAccent, size: 20)),
      title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blueAccent) : null,
      onTap: () => widget.onStrategyChanged(type),
    );
  }

  Widget _buildTimePickerButton(String label, TimeOfDay time, Function(TimeOfDay) onSelect, bool isDark) {
    return GestureDetector(
      onTap: () async {
        showGlassDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) {
             TimeOfDay temp = time;
             return Dialog(
               backgroundColor: Colors.transparent,
               child: GlassContainer(
                 width: 300, height: 300, borderRadius: 20, opacity: 0.95,
                 child: Column(
                   children: [
                     Padding(
                      padding: const EdgeInsets.all(16), 
                      child: Text(
                        "Chọn giờ", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)
                      )
                    ),
                     Expanded(child: CupertinoTheme(data: CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light), child: CupertinoDatePicker(mode: CupertinoDatePickerMode.time, initialDateTime: DateTime(2024,1,1,time.hour,time.minute), onDateTimeChanged: (val)=> temp = TimeOfDay(hour: val.hour, minute: val.minute)))),
                     Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: BouncingButton(onTap: (){ onSelect(temp); Navigator.pop(context); }, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(gradient: AppStyles.primaryGradient, borderRadius: BorderRadius.circular(12)), child: const Text("OK", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))))
                   ],
                 ),
               )
             );
          }
        );
      },
      child: Column(
        children: [
          Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          GlassContainer(width: 80, height: 36, borderRadius: 10, opacity: 0.3, child: Center(child: Text("${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Container(width: double.infinity, padding: const EdgeInsets.only(left: 10, bottom: 10), child: Text(title.toUpperCase(), style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)));
  }

  Widget _buildActionItem({required IconData icon, required String title, String? subtitle, required bool isDark, required VoidCallback onTap}) {
    return BouncingButton(onTap: onTap, child: ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: isDark ? Colors.white : Colors.blueAccent, size: 20)), title: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)), subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12)) : null, trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.white30 : Colors.black26)));
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
    return Center(child: GlassContainer(width: 250, height: 200, opacity: isDark ? 0.1 : 0.7, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 50, color: isDark ? Colors.white24 : Colors.black26), const SizedBox(height: 16), Text(text, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16))])));
  }
}

// --- BOUNCY BUTTON HELPER ---
class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const BouncingButton({super.key, required this.child, required this.onTap});
  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}
class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) { _controller.reverse(); widget.onTap(); },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// --- GLASS SWITCH TÙY CHỈNH ---
class GlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const GlassSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut, // Nảy như lò xo
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: value ? AppStyles.primaryGradient : null,
          color: value ? null : Colors.grey.withOpacity(0.4),
          boxShadow: [
            BoxShadow(
              color: value ? const Color(0xFF4FACFE).withOpacity(0.4) : Colors.transparent,
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
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
  const GlassContainer({super.key, required this.width, this.height, required this.child, this.borderRadius = 20.0, this.blur = 15.0, this.opacity = 0.1});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark ? Colors.white : Colors.white; 
    final borderColor = isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.6);
    return ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: Stack(children: [
        Positioned.fill(
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: Container(decoration: BoxDecoration(
            color: glassColor.withOpacity(isDark ? opacity : 0.7), 
            borderRadius: BorderRadius.circular(borderRadius), 
            border: Border.all(color: borderColor, width: 0.5), 
            boxShadow: isDark ? [] : [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: isDark ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.01)] : [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.6)], stops: const [0.0, 1.0])))),
        ),
        Container(width: width, height: height, padding: EdgeInsets.zero, child: child),
    ]));
  }
}