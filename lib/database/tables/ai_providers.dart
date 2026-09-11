import 'package:drift/drift.dart';

class AiProviders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type =>
      text().withLength(min: 1, max: 20)(); // openai, ollama, dify, custom
  TextColumn get baseUrl => text()();
  TextColumn get apiKey => text().nullable()();
  TextColumn get modelName => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get extraConfig => text().nullable()(); // JSON string
}
