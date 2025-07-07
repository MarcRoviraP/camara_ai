import 'package:camara_ai/screen/ImagePicker.dart';
import 'package:camara_ai/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(); // 👈 carga las variables del archivo .env

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.from(colorScheme: MaterialTheme.lightScheme()),
      darkTheme: ThemeData.from(colorScheme: MaterialTheme.darkScheme()),
      title: 'Camara AI',
      home: const ImagePickerScreen(),
    );
  }
}
