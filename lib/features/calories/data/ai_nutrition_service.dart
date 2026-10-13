import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import '../../settings/data/settings_repository.dart';

final aiNutritionServiceProvider = Provider<AiNutritionService?>((ref) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings?.geminiApiKey == null || settings!.geminiApiKey!.isEmpty) return null;
  return AiNutritionService(settings.geminiApiKey!);
});

class NutritionAnalysis {
  final int calories;
  final int protein;
  final int fats;
  final int carbs;
  final String markdownResponse;

  NutritionAnalysis({
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
    required this.markdownResponse,
  });
}

class AiNutritionService {
  final String apiKey;

  AiNutritionService(this.apiKey);

  Future<NutritionAnalysis?> analyzeFoodImage(
      File image, 
      int targetCalories, int targetProtein, int targetFats, int targetCarbs,
      int currentCalories, int currentProtein, int currentFats, int currentCarbs,
  ) async {


    final prompt = """
Ти — персональний нутриціолог та щоденник харчування. Твоє завдання — аналізувати фотографії їжі, розраховувати їхній КБЖУ (калорії, білки, жири, вуглеводи) та вести мій добовий підсумок.

🎯 МОЯ ДОБОВА НОРМА:
- Калорії: $targetCalories ккал
- Білки: $targetProtein г
- Жири: $targetFats г
- Вуглеводи: $targetCarbs г

🎯 СЬОГОДНІ ВЖЕ СПОЖИТО ДО ЦЬОГО ПРИЙОМУ:
- Калорії: $currentCalories ккал
- Білки: $currentProtein г
- Жири: $currentFats г
- Вуглеводи: $currentCarbs г

ПРАВИЛА РОБОТИ ТА СТРУКТУРА ВІДПОВІДІ:
1. Аналізуй страву на інгредієнти та вагу. Враховуй приховані інгредієнти.
2. Поверни сувору JSON структуру.

Схема JSON, яку ти МАЄШ повернути (БЕЗ маркдаун блоків, просто чистий JSON):
{
  "mealMacros": {
    "calories": <int>,
    "protein": <int>,
    "fats": <int>,
    "carbs": <int>
  },
  "markdownText": "<Тут встав текст у точному форматі вказаному нижче>"
}

Формат тексту для поля markdownText (використовуй завжди цей формат):
### 🍽 Прийом їжі: [Назва страви]
* **[Інгредієнт 1] (~X г):** X ккал | Б: Xг | Ж: Xг | В: Xг
* **[Інгредієнт 2] (~X г):** X ккал | Б: Xг | Ж: Xг | В: Xг
*(Разом за цей прийом: X ккал | Б: Xг | Ж: Xг | В: Xг)*

---
### 📊 ПРОГРЕС ЗА СЬОГОДНІ (враховуючи цей прийом):
* **Калорії:** [current + meal] / $targetCalories ккал *(Залишилось: [target - current - meal] ккал)*
* **Білки:** [current + meal] / $targetProtein г *(Залишилось: [target - current - meal] г)*
* **Жири:** [current + meal] / $targetFats г *(Залишилось: [target - current - meal] г)*
* **Вуглеводи:** [current + meal] / $targetCarbs г *(Залишилось: [target - current - meal] г)*

Додатково:
- Не додавай зайвих розмов.
- Якщо фото нечітке, зроби максимально точну оцінку та постав коротке уточнення наприкінці markdownText.
""";

    try {
      final bytes = await image.readAsBytes();
      final imagePart = DataPart('image/jpeg', bytes);

      // Models available and supported for Gemini API vision
      final modelsToTry = [
        'gemini-3.8-flash',
        'gemini-3.7-flash',
        'gemini-3.6-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.5-flash',
        'gemini-3.1-flash-lite',
        'gemini-flash-lite-latest',
        'gemini-flash-latest',
      ];
      GenerateContentResponse? response;
      List<String> allErrors = [];

      for (String modelName in modelsToTry) {
        // Retry loop for transient 503 / network errors
        int attempts = 0;
        const maxAttempts = 2;

        while (attempts < maxAttempts) {
          attempts++;
          try {
            final tempModel = GenerativeModel(
              model: modelName,
              apiKey: apiKey,
              generationConfig: GenerationConfig(
                temperature: 0.2,
                responseMimeType: 'application/json',
              ),
            );
            response = await tempModel.generateContent([
              Content.multi([TextPart(prompt), imagePart])
            ]).timeout(const Duration(seconds: 40));

            if (response.text != null && response.text!.isNotEmpty) {
              break; // Success
            }
          } catch (e) {
            final errorStr = e.toString();
            // If 503 (high demand) and we have attempts left, wait 1.5s and retry this model
            if ((errorStr.contains('503') || errorStr.contains('high demand') || errorStr.contains('UNAVAILABLE')) && attempts < maxAttempts) {
              print('Model $modelName 503 spike, waiting 1.5s before retry...');
              await Future.delayed(const Duration(milliseconds: 1500));
              continue;
            }

            allErrors.add('$modelName: $e');
            print('Model $modelName failed (attempt $attempts): $e');
            try {
              final dir = await getApplicationDocumentsDirectory();
              final logFile = File('${dir.path}/flutter_model_errors.log');
              logFile.writeAsStringSync('Model $modelName failed: $e\n', mode: FileMode.append);
            } catch (_) {}
            break; // Move to next model
          }
        }

        if (response != null && response.text != null && response.text!.isNotEmpty) {
          break; // Found successful response
        }
      }

      if (response == null || response.text == null) {
        // Fetch available models to show in error
        String availableModels = "Не вдалося отримати список моделей";
        try {
          final res = await http.get(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey'));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final models = data['models'] as List?;
            if (models != null) {
              final names = models.map((m) => m['name'].toString().replaceAll('models/', '')).toList();
              availableModels = names.join(', ');
            } else {
              availableModels = "Список порожній";
            }
          } else {
            availableModels = "Помилка ${res.statusCode}: ${res.body}";
          }
        } catch (e) {
          availableModels = "Помилка HTTP: $e";
        }
        
        throw Exception('Всі моделі недоступні! \nПомилки: ${allErrors.join(' | ')}\nДоступні вам: $availableModels');
      }

      if (response.text == null) return null;

      String text = response.text!.trim();
      if (text.startsWith('```json')) {
        text = text.substring(7);
      } else if (text.startsWith('```')) {
        text = text.substring(3);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      final Map<String, dynamic> data = jsonDecode(text.trim());
      
      return NutritionAnalysis(
        calories: data['mealMacros']?['calories']?.toInt() ?? 0,
        protein: data['mealMacros']?['protein']?.toInt() ?? 0,
        fats: data['mealMacros']?['fats']?.toInt() ?? 0,
        carbs: data['mealMacros']?['carbs']?.toInt() ?? 0,
        markdownResponse: data['markdownText'] ?? '',
      );
    } catch (e) {
      print('Error parsing gemini response: $e');
      rethrow;
    }
  }
}
