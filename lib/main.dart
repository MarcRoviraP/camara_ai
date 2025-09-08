import 'package:camara_ai/screen/ImagePicker.dart';
import 'package:camara_ai/theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await dotenv.load(); // 👈 carga las variables del archivo .env

  runApp(
     EasyLocalization(
      supportedLocales: [const Locale('en'), const Locale('es')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: context.locale,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.from(colorScheme: MaterialTheme.lightScheme()),
      darkTheme: ThemeData.from(colorScheme: MaterialTheme.darkScheme()),
      title: 'Camara AI',
      home: const ImagePickerScreen(),
    );
  }
}
