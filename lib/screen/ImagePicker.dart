import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ImagePickerScreen extends StatefulWidget {
  const ImagePickerScreen({super.key});

  @override
  State<ImagePickerScreen> createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  File? _imageFile;
  String _aiResult = '';
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
  );

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _aiResult = ''; // Limpiar resultado previo
      });
    }
  }

  Future<void> _analyzeImageWithAI() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
      _aiResult = '';
    });

    final imageBytes = await _imageFile!.readAsBytes();
    final prompt = TextPart(
      "Describe esta imagen. Si contiene texto, resúmelo citando los puntos clave. Si no, describe el contenido visual.",
    );
    final imagePart = DataPart('image/jpeg', imageBytes);

    try {
      final response = await model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final output = response.text ?? "No se obtuvo respuesta de Gemini.";
      setState(() {
        _aiResult = output;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _aiResult = "❌ Error al consultar Gemini:\n$e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona una imagen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _imageFile!,
                        width: 300,
                        height: 300,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Text(
                      'No hay imagen seleccionada',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _imageFile == null || _isLoading ? null : _analyzeImageWithAI,
              icon: const Icon(Icons.search),
              label: const Text('Buscar con IA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            if (_isLoading) const CircularProgressIndicator(),
            if (_aiResult.isNotEmpty) ...[
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Resultado IA:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              MarkdownBody(data: _aiResult),
            ],
          ],
        ),
      ),
    );
  }
}
