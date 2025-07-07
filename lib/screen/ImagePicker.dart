import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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
  int currentPromptIndex = 0;
  TextPart prompt = TextPart(
    "Analiza detalladamente la imagen proporcionada. Si contiene texto, resume los mensajes principales de forma clara y concisa, citando frases clave si son relevantes. Si no hay texto, describe los elementos visuales, su contexto y posibles interpretaciones. Sé preciso y objetivo.",
  );
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
      appBar: AppBar(title: const Text('')),
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
            if (_imageFile != null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: currentPromptIndex == 0
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            )
                          : null,
                      onPressed: () {
                        prompt = TextPart(
                          "Analiza detalladamente la imagen proporcionada. Si contiene texto, resume los mensajes principales de forma clara y concisa, citando frases clave si son relevantes. Si no hay texto, describe los elementos visuales, su contexto y posibles interpretaciones. Sé preciso y objetivo.",
                        );
                        setState(() {
                          currentPromptIndex = 0;
                        });
                      },
                      icon: Icon(Icons.image_search),
                      label: Text("Analizar imagen"),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: currentPromptIndex == 1
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            )
                          : null,
                      onPressed: () {
                        prompt = TextPart(
                          "Observa esta imagen e identifica los productos que aparecen, describiendo sus características visibles (tipo, color, forma, material, marca, etiquetas u otros detalles distintivos) y cualquier texto asociado. Si puedes reconocer alguno, busca información adicional como precios estimados, tiendas donde puede comprarse, valoraciones de usuarios o usos comunes. Si los productos no son claramente identificables por baja calidad, ángulo, iluminación o falta de detalles, indícalo explícitamente y sugiere subir una imagen más clara o desde otro ángulo. No generes análisis si no estás seguro de la identidad del producto.",
                        );
                        setState(() {
                          currentPromptIndex = 1;
                        });
                      },
                      icon: Icon(Icons.shopping_bag),
                      label: Text("Analizar productos"),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: currentPromptIndex == 2
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            )
                          : null,
                      onPressed: () {
                        prompt = TextPart(
                          "Explica detalladamente el siguiente texto extraído de una imagen. Describe su significado, propósito, contexto posible y cualquier término relevante que pueda requerir aclaración. Si se trata de un documento formal, publicitario, técnico o educativo, indícalo. Usa un lenguaje claro y estructurado para facilitar la comprensión.",
                        );
                        setState(() {
                          currentPromptIndex = 2;
                        });
                      },
                      icon: Icon(Icons.text_snippet),
                      label: Text("Buscar texto"),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _imageFile == null || _isLoading
                  ? null
                  : _analyzeImageWithAI,
              icon: const Icon(Icons.search),
              label: const Text('Buscar con IA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              Center(
                child: SpinKitSpinningLines(
                  color: Theme.of(context).colorScheme.primary,
                  size: 100.0,
                ),
              ),
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
              MarkdownBody(data: _aiResult, selectable: true),
            ],
          ],
        ),
      ),
    );
  }
}
