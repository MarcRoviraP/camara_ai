import 'package:camara_ai/generated/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatMessageData {
  final String role; // "user" o "assistant"
  final String content; // texto o ruta de imagen
  final bool isImage;
  final DateTime timestamp;

  ChatMessageData({
    required this.role,
    required this.content,
    this.isImage = false,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'isImage': isImage,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessageData.fromJson(Map<String, dynamic> json) =>
      ChatMessageData(
        role: json['role'],
        content: json['content'],
        isImage: json['isImage'] ?? false,
        timestamp: DateTime.parse(json['timestamp']),
      );
}

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
  final TextEditingController _textController = TextEditingController();
  List<ChatMessageData> historial = [];
  List<String> prompts = [
  "Mira la imagen con atención: si contiene texto, destila sus mensajes principales y rescata las frases que marcan la diferencia. Si no hay letras a la vista, centra tu relato en los elementos visuales más claros y representativos, siempre con objetividad.",
  
  "Observa los productos en la escena y pinta con palabras lo que se ve: tipo, color, forma, material, marca, etiquetas o texto visible. Si el contexto lo permite y la certeza acompaña, añade detalles como precios aproximados o lugares donde podrían encontrarse. Si no, deja que lo esencial hable por sí mismo.",
  
  "Detente en los animales presentes en la imagen y describe sus rasgos visibles: tamaño, colores, forma, comportamiento. Cuando la certeza lo haga posible, revela su nombre común, el hábitat que los define y alguna curiosidad que los haga únicos. Si se prestan a la caza o pesca, señala el método más adecuado. Pero si la duda asoma, mejor guarda silencio en lugar de inventar.",
  
  "Explora el texto extraído de la imagen y desvela su intención: resume su propósito, marca su tono y define su tema central. Finalmente, sitúalo en su contexto: ¿es formal, publicitario, técnico o educativo?",
];


  TextPart prompt = TextPart(
    
    "Analiza la imagen. Si tiene texto, resume los mensajes principales y cita frases clave. Si no, describe los elementos visuales, contexto e interpretaciones posibles de manera precisa y objetiva.",
  );

  final ImagePicker _picker = ImagePicker();

  late final GenerativeModel model;
  late ChatSession chat; // mantiene el contexto

  @override
  void initState() {
    super.initState();
    model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
    );
    chat = model.startChat(); // inicializar chat
    _cargarHistorial();
  }

  Future<void> _guardarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = historial.map((msg) => msg.toJson()).toList();
    prefs.setString('chat_historial', jsonEncode(jsonList));
  }

  Future<void> _cargarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('chat_historial');
    if (jsonString == null) return;

    final List<dynamic> jsonList = jsonDecode(jsonString);
    historial = jsonList.map((e) => ChatMessageData.fromJson(e)).toList();

    // Reconstruir la sesión en memoria
    for (var msg in historial) {
      if (msg.isImage) {
        final imageBytes = File(msg.content).readAsBytesSync();
        await chat.sendMessage(
          Content.multi([DataPart('image/jpeg', imageBytes)]),
        );
      } else {
        await chat.sendMessage(Content.text(msg.content));
      }
    }

    setState(() {});
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _aiResult = '';
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
      final response = await chat.sendMessage(
        Content.multi([prompt, imagePart]),
      );

      final output = response.text ?? LocaleKeys.ImagePicker_no_gemini_answer.tr();
      setState(() {
        _aiResult = output;
        _isLoading = false;
      });
      // Guardar en historial
      historial.add(
        ChatMessageData(
          role: "user",
          content: _imageFile!.path,
          isImage: true,
          timestamp: DateTime.now(),
        ),
      );
      historial.add(
        ChatMessageData(
          role: "assistant",
          content: output,
          isImage: false,
          timestamp: DateTime.now(),
        ),
      );
      _guardarHistorial();
    } catch (e) {
      setState(() {
        _aiResult = "${LocaleKeys.ImagePicker_error_querying_gemini.tr()}\n$e";
        _isLoading = false;
      });
    }
    _imageFile = null;
  }

  /// Continuar conversación, enviando siempre imagen y texto aunque la imagen no haya cambiado
  Future<void> _continueConversation(String text) async {
    setState(() {
      _isLoading = true;
      _aiResult = '';
    });

    try {
      if (_imageFile != null) {
        final imageBytes = await _imageFile!.readAsBytes();
        final imagePart = DataPart('image/jpeg', imageBytes);
        final response = await chat.sendMessage(
          Content.multi([TextPart(text), imagePart]),
        );
        final output = response.text ?? LocaleKeys.ImagePicker_no_gemini_answer.tr();
        setState(() {
          _aiResult = output;
          _isLoading = false;
        });
      } else {
        // Si no hay imagen, solo envía el texto
        final response = await chat.sendMessage(Content.text(text));
        final output = response.text ?? LocaleKeys.ImagePicker_no_gemini_answer.tr();
        setState(() {
          _aiResult = output;
          _isLoading = false;
        });
        // Guardar en historial
        if (_imageFile != null) {
          historial.add(
            ChatMessageData(
              role: "user",
              content: _imageFile!.path,
              isImage: true,
              timestamp: DateTime.now(),
            ),
          );
        }
        historial.add(
          ChatMessageData(
            role: "user",
            content: text,
            isImage: false,
            timestamp: DateTime.now(),
          ),
        );
        historial.add(
          ChatMessageData(
            role: "assistant",
            content: output,
            isImage: false,
            timestamp: DateTime.now(),
          ),
        );
        _guardarHistorial();
      }
    } catch (e) {
      setState(() {
        _aiResult = "${LocaleKeys.ImagePicker_error_querying_gemini.tr()}\n$e";
        _isLoading = false;
      });
    }
    _imageFile = null;
  }

  /// Cambia la imagen actual por una nueva seleccionada de la galería
  Future<void> _refreshNewImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
    });
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
                  :  Text(
                      LocaleKeys.ImagePicker_no_selected_image.tr(),
                      style: TextStyle(fontSize: 18),
                    ),
            ),
            const SizedBox(height: 20),

            /// Botones de cámara y galería
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(LocaleKeys.ImagePicker_camara.tr()),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(LocaleKeys.ImagePicker_gallery.tr()),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// Botones de prompts
            if (_imageFile != null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
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
                          prompts[0],
                        );
                        setState(() {
                          currentPromptIndex = 0;
                        });
                      },
                      icon: const Icon(Icons.image_search),
                      label:  Text(LocaleKeys.ImagePicker_inspect_image.tr()),
                    ),
                    const SizedBox(width: 10),
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
                          prompts[1],
                        );
                        setState(() {
                          currentPromptIndex = 1;
                        });
                      },
                      icon: const Icon(Icons.shopping_bag),
                      label: Text(LocaleKeys.ImagePicker_inspect_products.tr()),
                    ),
                    const SizedBox(width: 10),
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
                          prompts[2],
                        );
                        setState(() {
                          currentPromptIndex = 2;
                        });
                      },
                      icon: const Icon(Icons.pets),
                      label: Text(LocaleKeys.ImagePicker_inspect_animals.tr()),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: currentPromptIndex == 3
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            )
                          : null,
                      onPressed: () {
                        prompt = TextPart(
                          prompts[3],
                        );
                        setState(() {
                          currentPromptIndex = 3;
                        });
                      },
                      icon: const Icon(Icons.text_snippet),
                      label: Text(LocaleKeys.ImagePicker_looking_for_text.tr()),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            /// Botón buscar con IA
            ElevatedButton.icon(
              onPressed: _imageFile == null || _isLoading
                  ? null
                  : _analyzeImageWithAI,
              icon: const Icon(Icons.search),
              label: Text(LocaleKeys.ImagePicker_searchin_with_ia.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onPrimary,
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
               Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  LocaleKeys.ImagePicker_ai_result.tr(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              MarkdownBody(data: _aiResult, selectable: true),

              const SizedBox(height: 20),
            ],

            /// Input de texto + enviar y botón nueva imagen
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration:  InputDecoration(
                      hintText: LocaleKeys.ImagePicker_ask_a_question.tr(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final text = _textController.text;
                    _textController.clear();
                    if (text.isNotEmpty) _continueConversation(text);
                  },
                ),
                IconButton(
                  icon:  Icon(Icons.add_photo_alternate),
                  tooltip: LocaleKeys.ImagePicker_reload_image.tr(),
                  onPressed: _refreshNewImage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
