import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_assistant/core/models/assistant_state.dart';
import 'package:ai_assistant/features/assistant/widgets/orb_widget.dart';
import 'assistant_provider.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    _textController.addListener(() {
      if (_textController.text.isNotEmpty) {
        ref.read(assistantProvider.notifier).clearResponse();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _initWindowsVoice());
  }

  Future<void> _initWindowsVoice() async {
    if (!Platform.isWindows) return;

    final prefs = await SharedPreferences.getInstance();
    final savedMicId = prefs.getString('selected_mic_id');
    final notifier = ref.read(assistantProvider.notifier);

    if (savedMicId == null) {
      if (mounted) _showMicPicker();
    } else {
      await notifier.initializeWindowsEngine(savedMicId);
    }
  }

  void _showMicPicker() async {
    final notifier = ref.read(assistantProvider.notifier);
    final devices = await notifier.getAvailableMicrophones();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1128),
        title: const Text(
          "Select Microphone",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final d = devices[index];
              return ListTile(
                leading: const Icon(Icons.mic, color: Color(0xFF5C7AEA)),
                title: Text(
                  d.label,
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('selected_mic_id', d.id);
                  await notifier.initializeWindowsEngine(d.id);
                  if (mounted) Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onOrbTap() {
    final notifier = ref.read(assistantProvider.notifier);
    final assistant = ref.read(assistantProvider);
    final state = assistant.state;

    if (state == AssistantState.listening) {
      notifier.stopListening();
    } else {
      notifier.startListening();
    }
  }

  void _sendText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    ref.read(assistantProvider.notifier).handleTextInput(trimmed);
    _textController.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final assistant = ref.watch(assistantProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF080A18),
      resizeToAvoidBottomInset: true,
      endDrawer: _buildSettingsDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OrbWidget(
                      state: assistant.state,
                      waveAmplitudes: assistant.waveAmplitudes,
                      onTap: _onOrbTap,
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        assistant.state.label,
                        key: ValueKey(assistant.state),
                        style: const TextStyle(
                          color: Color(0xFF5C7AEA),
                          letterSpacing: 1.5,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (assistant.transcribedText != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          assistant.transcribedText!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8899CC),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (assistant.responseText != null)
                      _buildResponseText(assistant.responseText!),
                  ],
                ),
              ),
            ),
            _buildTextInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.history_rounded,
              color: Color(0xFF3D5A99),
              size: 22,
            ),
          ),
          const Text(
            'ARIA',
            style: TextStyle(
              color: Color(0xFF3D5A99),
              letterSpacing: 6,
              fontSize: 13,
              fontWeight: FontWeight.w300,
            ),
          ),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(
              Icons.tune_rounded,
              color: Color(0xFF3D5A99),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0D1128),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF080A18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'SETTINGS',
                  style: TextStyle(
                    color: Color(0xFF5C7AEA),
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Configure your Assistant',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.key, color: Colors.amber),
            title: const Text(
              'Update API Key',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => _showApiKeyDialog(),
          ),
          if (Platform.isWindows)
            ListTile(
              leading: const Icon(Icons.mic, color: Colors.blueAccent),
              title: const Text(
                'Change Microphone',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _showMicPicker();
              },
            ),
          const Divider(color: Colors.white10),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              Platform.isAndroid
                  ? "Platform: Android Mobile"
                  : "Platform: Windows Desktop",
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1128),
        title: const Text(
          "Groq API Key",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Paste gsk_...",
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                // Simplified: Uses the same storage as provider
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('groq_api_key', controller.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseText(String text) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1535).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A3A8A).withOpacity(0.4)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFFCDD5F3),
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildTextInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: const TextStyle(color: Color(0xFFCDD5F3)),
              decoration: InputDecoration(
                hintText: 'Ask anything...',
                hintStyle: const TextStyle(color: Color(0xFF2A3A6A)),
                filled: true,
                fillColor: const Color(0xFF0D1128),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: _sendText,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _sendText(_textController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF4361EE), Color(0xFF7209B7)],
                ),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
