import 'package:flutter/material.dart';
import '../../widgets/ai_chat_panel.dart';
import '../../widgets/glass_container.dart';

class AiChatPage extends StatelessWidget {
  const AiChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: stableSurfaceColor(context),
      appBar: AppBar(title: const Text('AI 助手')),
      body: const AiChatPanel(),
    );
  }
}
