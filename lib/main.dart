import 'package:final_project/Route/app_page.dart';
import 'package:final_project/Route/app_route.dart';
import 'package:final_project/cor/constants.dart';
import 'package:final_project/view_models/bookmarke_controller.dart';
import 'package:final_project/view_models/search_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _setup();
  Get.put(SearchControllerrr());
  Get.put(BookmarkController());
  await GetStorage.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  var prefs = await SharedPreferences.getInstance();
  userName = prefs.getString('fullName') ?? '';
  isLoggedin = prefs.getBool('isLoggedin') ?? false;
  isDark = prefs.getBool('isDark') ?? false;
  email = prefs.getString('email') ?? '';

  runApp(const MyApp());
}

Future<void> _setup() async {
  Stripe.publishableKey = stripePublishableKey;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        print('==User is currently signed out!==');
      } else {
        print('=== User is signed in! ===');
      }
    });
    requestNotificationPermission();
    super.initState();
  }

  Future<void> requestNotificationPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ تم السماح بالإشعارات');
    } else {
      print('❌ تم رفض الإشعارات');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: isLoggedin == false ? AppRoute.splashScreen : AppRoute.home,
      getPages: appPage,
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
    );
  }
}
