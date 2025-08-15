import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'auth_page.dart';
import 'mistake_book_n.dart';
import 'chat_page_s.dart';
import 'onboarding_chat.dart';

import 'login_page.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

// Semantic color tokens used across the app (excluding homepage visuals)
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color brandBackgroundDeep; // 0xFF102031
  final Color brandPrimary;        // 0xFF1E3875
  final Color brandSecondary;      // 0xFF2D7A8F
  final Color surfaceDeep;         // 0xFF1B3B4B

  // Blues used in multiple pages
  final Color oceanAqua;           // 0xFF319CB6
  final Color textBlue;            // 0xFF0777B1
  final Color altPrimaryBlue;      // 0xFF1E5B8C
  final Color altSecondaryBlue;    // 0xFF2A7AB8
  final Color lightBlue;           // 0xFF8BB7E0
  final Color cardBlue;            // 0xFFECF6F9

  // Accents
  final Color accentOrange;        // 0xFFF59B03
  final Color accentOrangeSoft;    // 0xFFFFA368

  // Feedback
  final Color success;             // 0xFF4CAF50 / 0xFF10B981
  final Color error;               // 0xFFEF4444
  final Color correct;             // 0xFF4ADE80
  final Color incorrect;           // 0xFFF87171

  const AppColors({
    required this.brandBackgroundDeep,
    required this.brandPrimary,
    required this.brandSecondary,
    required this.surfaceDeep,
    required this.oceanAqua,
    required this.textBlue,
    required this.altPrimaryBlue,
    required this.altSecondaryBlue,
    required this.lightBlue,
    required this.cardBlue,
    required this.accentOrange,
    required this.accentOrangeSoft,
    required this.success,
    required this.error,
    required this.correct,
    required this.incorrect,
  });

  @override
  AppColors copyWith({
    Color? brandBackgroundDeep,
    Color? brandPrimary,
    Color? brandSecondary,
    Color? surfaceDeep,
    Color? oceanAqua,
    Color? textBlue,
    Color? altPrimaryBlue,
    Color? altSecondaryBlue,
    Color? lightBlue,
    Color? cardBlue,
    Color? accentOrange,
    Color? accentOrangeSoft,
    Color? success,
    Color? error,
    Color? correct,
    Color? incorrect,
  }) {
    return AppColors(
      brandBackgroundDeep: brandBackgroundDeep ?? this.brandBackgroundDeep,
      brandPrimary: brandPrimary ?? this.brandPrimary,
      brandSecondary: brandSecondary ?? this.brandSecondary,
      surfaceDeep: surfaceDeep ?? this.surfaceDeep,
      oceanAqua: oceanAqua ?? this.oceanAqua,
      textBlue: textBlue ?? this.textBlue,
      altPrimaryBlue: altPrimaryBlue ?? this.altPrimaryBlue,
      altSecondaryBlue: altSecondaryBlue ?? this.altSecondaryBlue,
      lightBlue: lightBlue ?? this.lightBlue,
      cardBlue: cardBlue ?? this.cardBlue,
      accentOrange: accentOrange ?? this.accentOrange,
      accentOrangeSoft: accentOrangeSoft ?? this.accentOrangeSoft,
      success: success ?? this.success,
      error: error ?? this.error,
      correct: correct ?? this.correct,
      incorrect: incorrect ?? this.incorrect,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brandBackgroundDeep: Color.lerp(brandBackgroundDeep, other.brandBackgroundDeep, t)!,
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      brandSecondary: Color.lerp(brandSecondary, other.brandSecondary, t)!,
      surfaceDeep: Color.lerp(surfaceDeep, other.surfaceDeep, t)!,
      oceanAqua: Color.lerp(oceanAqua, other.oceanAqua, t)!,
      textBlue: Color.lerp(textBlue, other.textBlue, t)!,
      altPrimaryBlue: Color.lerp(altPrimaryBlue, other.altPrimaryBlue, t)!,
      altSecondaryBlue: Color.lerp(altSecondaryBlue, other.altSecondaryBlue, t)!,
      lightBlue: Color.lerp(lightBlue, other.lightBlue, t)!,
      cardBlue: Color.lerp(cardBlue, other.cardBlue, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      accentOrangeSoft: Color.lerp(accentOrangeSoft, other.accentOrangeSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      correct: Color.lerp(correct, other.correct, t)!,
      incorrect: Color.lerp(incorrect, other.incorrect, t)!,
    );
  }

  static const AppColors defaults = AppColors(
    brandBackgroundDeep: Color(0xFF102031),
    brandPrimary: Color(0xFF1E3875),
    brandSecondary: Color(0xFF2D7A8F),
    surfaceDeep: Color(0xFF1B3B4B),
    oceanAqua: Color(0xFF319CB6),
    textBlue: Color(0xFF0777B1),
    altPrimaryBlue: Color(0xFF1E5B8C),
    altSecondaryBlue: Color(0xFF2A7AB8),
    lightBlue: Color(0xFF8BB7E0),
    cardBlue: Color(0xFFECF6F9),
    accentOrange: Color(0xFFF59B03),
    accentOrangeSoft: Color(0xFFFFA368),
    success: Color(0xFF4CAF50),
    error: Color(0xFFEF4444),
    correct: Color(0xFF4ADE80),
    incorrect: Color(0xFFF87171),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sdjytgbojqslkfwfxlvs.supabase.co', // Bo
    // url: 'https://zgccuixkrlsfmsgblbpe.supabase.co', // Pierre
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNkanl0Z2JvanFzbGtmd2Z4bHZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA0NjEwNjUsImV4cCI6MjA1NjAzNzA2NX0.IAFreOpeUF0qxKyWaEbpyG3eQPWS3F58XisraV_Z8S8', // Bo
    // anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpnY2N1aXhrcmxzZm1zZ2JsYnBlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU5NjI3MzksImV4cCI6MjA1MTUzODczOX0.6SVEK8ib3RDeQ7-Qj3oGUU6e0j_baKkfhH6MoL03sQM', // Pierre
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // // Initialize Firebase Messaging
  // final messaging = FirebaseMessaging.instance;

  // // Request permission for iOS
  // await messaging.requestPermission(
  //   alert: true,
  //   badge: true,
  //   sound: true,
  // );

  // // Get APNS token
  // final apnsToken = await messaging.getAPNSToken();
  // print('APNS Token: $apnsToken');

  // // Get FCM token
  // final fcmToken = await messaging.getToken();
  // print('FCM Token: $fcmToken');
  // Firebase Messaging 將在用戶登入後透過 NotificationService.init() 進行初始化

  // 初始化 Hive
  // 這樣能載入之前的錯題？
  await Hive.initFlutter();
  await Hive.openBox('questionsBox');

  final dir = await getApplicationDocumentsDirectory();
  print("Hive 資料會儲存在這裡：${dir.path}");

  //await NotificationService.init(); // ← 在這裡初始化推播，包含 token 取得與上傳邏輯

  /*
  // 暫時列出並清空 shared_preferences 的所有鍵值對
  SharedPreferences prefs = await SharedPreferences.getInstance();
  print("SharedPreferences 中的所有鍵值對：");
  prefs.getKeys().forEach((key) {
    print("$key: ${prefs.get(key)}");
  });
  await prefs.clear();
  print("已清空 SharedPreferences");
  */

  runApp(MyApp());
}

// MyApp: 應用程序的根組件
// 負責設置應用的整體主題、顏色方案和字體樣式
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 學習助手',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Color(0xFF102031), // 深藍色微偏綠
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF102031), // 藍綠色
          secondary: Color(0xFF2D7A8F), // 淺藍綠色
          surface: Color(0xFF1B3B4B), // 深藍色微偏綠
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(
              fontSize: 40,
              fontFamily: 'Heavy',
              fontWeight: FontWeight.bold,
              color: Colors.white),
          displayMedium: TextStyle(
              fontSize: 32,
              fontFamily: 'Medium',
              fontWeight: FontWeight.w600,
              color: Colors.white),
          bodyLarge: TextStyle(
              fontSize: 20,
              fontFamily: 'Normal',
              fontWeight: FontWeight.normal,
              color: Colors.white70),
          bodyMedium: TextStyle(
              fontSize: 16,
              fontFamily: 'Normal',
              fontWeight: FontWeight.normal,
              color: Colors.white70),
        ),
        extensions: const <ThemeExtension<dynamic>>[
          AppColors.defaults,
        ],
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginPage(),
        '/home': (context) => HomePage(),
        '/chat': (context) => ChatPage(),
        '/auth': (context) => AuthPage(),
        '/mistakes': (context) => MistakeBookPage(),
        '/onboarding': (context) => OnboardingChat(),
      },
    );
  }
}
