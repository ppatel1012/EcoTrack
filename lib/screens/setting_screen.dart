import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/eco_header.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  double _textScale = 1.0;
  bool _isDarkMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // No signed-in user – just show defaults.
        setState(() => _isLoading = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data() ?? {};

      // Safely parse values – Firestore may store them as int/num.
      final dark = (data['isDarkMode'] ?? false) as bool;

      final dynamic rawScale = data['textScale'] ?? 1.0;
      final double scale = rawScale is num ? rawScale.toDouble() : 1.0;

      setState(() {
        _isDarkMode = dark;
        _textScale = scale.clamp(0.8, 2.0);
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load settings.')),
        );
      }
    }
  }

  Future<void> _saveUserSettings({bool? isDarkMode, double? textScale}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        if (isDarkMode != null) 'isDarkMode': isDarkMode,
        if (textScale != null) 'textScale': textScale,
      }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save settings.')));
    }
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    _saveUserSettings(isDarkMode: _isDarkMode);
  }

  void _updateTextScale(double value) {
    setState(() {
      _textScale = value;
    });
  }

  void _commitTextScale(double value) {
    _saveUserSettings(textScale: value);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDarkMode ? Colors.black : Colors.white;
    final primaryTextColor = _isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: const EcoTrackHeader(),
      backgroundColor: bgColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back arrow under header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: _isDarkMode
                        ? const Color.fromARGB(255, 114, 220, 136)
                        : const Color(0xFF204E2A),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Title under the arrow
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 20 * _textScale,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),
                ),

                // Main settings
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dark mode toggle button
                        ElevatedButton.icon(
                          onPressed: _toggleDarkMode,
                          icon: Icon(
                            _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            color: Colors.white,
                          ),
                          label: Text(
                            _isDarkMode
                                ? 'Disable Dark Mode'
                                : 'Enable Dark Mode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16 * _textScale,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isDarkMode
                                ? Colors.grey[800]
                                : Colors.green[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Text size section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Text Size',
                              style: TextStyle(
                                fontSize: 18 * _textScale,
                                color: primaryTextColor,
                              ),
                            ),
                            Text(
                              '${(_textScale * 100).round()}%',
                              style: TextStyle(
                                fontSize: 18 * _textScale,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          min: 0.8,
                          max: 2.0,
                          divisions: 12,
                          value: _textScale,
                          label: '${(_textScale * 100).round()}%',
                          onChanged: _updateTextScale,
                          onChangeEnd: _commitTextScale,
                        ),

                        // FAQ Section
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 16.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            'FAQ',
                            style: TextStyle(
                              fontSize: 18 * _textScale,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                        ),

                        _buildFaqTile(
                          context: context,
                          title: 'How does EcoTrack work?',
                          body:
                              'EcoTrack helps you track your sustainable activities — like recycling, reducing waste, and saving energy. '
                              'You can log actions, view progress, and share your achievements.',
                          isDarkMode: _isDarkMode,
                          textScale: _textScale,
                        ),

                        const SizedBox(height: 10),

                        _buildFaqTile(
                          context: context,
                          title: 'How do I change my username?',
                          body:
                              'Go to your Profile page, tap “Edit Profile,” and enter your new username. '
                              'Your changes will automatically save after confirmation.',
                          isDarkMode: _isDarkMode,
                          textScale: _textScale,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFaqTile({
    required BuildContext context,
    required String title,
    required String body,
    required bool isDarkMode,
    required double textScale,
  }) {
    final bgColor = isDarkMode ? Colors.grey[900] : Colors.grey[200];
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final bodyColor = isDarkMode ? Colors.grey[300] : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: isDarkMode
              ? const Color(0xFF81C784)
              : const Color(0xFF204E2A),
          collapsedIconColor: isDarkMode
              ? const Color(0xFF81C784)
              : const Color(0xFF204E2A),
          title: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w500,
              fontSize: 16 * textScale,
            ),
          ),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          children: [
            Text(
              body,
              style: TextStyle(fontSize: 16 * textScale, color: bodyColor),
            ),
          ],
        ),
      ),
    );
  }
}
