import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/shared.dart';

class PasswordGeneratorScreen extends StatefulWidget {
  const PasswordGeneratorScreen({super.key});

  @override
  State<PasswordGeneratorScreen> createState() =>
      _PasswordGeneratorScreenState();
}

class _PasswordGeneratorScreenState extends State<PasswordGeneratorScreen> {
  // Generator options
  double _length = 16;
  bool _useUppercase = true;
  bool _useLowercase = true;
  bool _useNumbers = true;
  bool _useSymbols = true;

  String _generatedPassword = '';
  bool _copied = false;

  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numbers = '0123456789';
  static const String _symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  // Password generation
  void _generate() {
    String charset = '';
    List<String> guaranteed = [];

    if (_useLowercase) {
      charset += _lowercase;
      guaranteed.add(_pick(_lowercase));
    }
    if (_useUppercase) {
      charset += _uppercase;
      guaranteed.add(_pick(_uppercase));
    }
    if (_useNumbers) {
      charset += _numbers;
      guaranteed.add(_pick(_numbers));
    }
    if (_useSymbols) {
      charset += _symbols;
      guaranteed.add(_pick(_symbols));
    }

    // Need at least one charset selected
    if (charset.isEmpty) {
      setState(() {
        _generatedPassword = '';
        _copied = false;
      });
      return;
    }

    int length = _length.round();
    Random random = Random.secure();

    // Fill remaining slots randomly
    List<String> chars = List.generate(
      length - guaranteed.length,
      (_) => charset[random.nextInt(charset.length)],
    );

    // Merge guaranteed + random, then shuffle
    List<String> all = [...guaranteed, ...chars];
    all.shuffle(random);

    setState(() {
      _generatedPassword = all.join();
      _copied = false;
    });
  }

  String _pick(String charset) {
    return charset[Random.secure().nextInt(charset.length)];
  }

  // Password strength
  int _score(String password) {
    if (password.isEmpty) return 0;
    int score = 0;

    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*()\-_=+\[\]{}|;:,.<>?]').hasMatch(password)) score++;

    return score.clamp(0, 7);
  }

  String _label(int score) {
    if (score <= 2) return 'Weak';
    if (score <= 4) return 'Fair';
    if (score <= 5) return 'Good';
    return 'Strong';
  }

  Color _color(int score) {
    if (score <= 2) return Shared.error;
    if (score <= 4) return const Color(0xFFFF9800);
    if (score <= 5) return const Color(0xFFFFEB3B);
    return Shared.success;
  }

  // Copy
  Future<void> _copy() async {
    if (_generatedPassword.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _generatedPassword));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  // Build
  Widget build(BuildContext context) {
    int score = _score(_generatedPassword);

    return Scaffold(
      backgroundColor: Shared.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Shared.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Password Generator',
                    style: TextStyle(
                      color: Shared.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Generated password display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Shared.surface,
                  borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
                  border: Border.all(color: Shared.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Password text
                    Text(
                      _generatedPassword.isEmpty
                          ? 'Select at least one character type'
                          : _generatedPassword,
                      style: TextStyle(
                        color: _generatedPassword.isEmpty
                            ? Shared.textSecondary
                            : Shared.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Strength bar
                    if (_generatedPassword.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: score / 7,
                                minHeight: 6,
                                backgroundColor: Shared.border,
                                valueColor: AlwaysStoppedAnimation(
                                  _color(score),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _label(score),
                            style: TextStyle(
                              color: _color(score),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _actionButton(
                            icon: Icons.refresh,
                            label: 'Regenerate',
                            onTap: _generate,
                            color: Shared.gold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _actionButton(
                            icon: _copied ? Icons.check : Icons.copy_outlined,
                            label: _copied ? 'Copied!' : 'Copy',
                            onTap: _copy,
                            color: _copied
                                ? Shared.success
                                : Shared.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Options
              _sectionLabel('Options'),

              // Length slider
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Shared.surface,
                  borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
                  border: Border.all(color: Shared.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Length',
                          style: TextStyle(
                            color: Shared.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Shared.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_length.round()}',
                            style: const TextStyle(
                              color: Shared.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Shared.gold,
                        inactiveTrackColor: Shared.border,
                        thumbColor: Shared.gold,
                        overlayColor: Shared.gold.withAlpha(30),
                      ),
                      child: Slider(
                        value: _length,
                        min: 6,
                        max: 64,
                        divisions: 58,
                        onChanged: (v) {
                          setState(() => _length = v);
                          _generate();
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '6',
                          style: TextStyle(
                            color: Shared.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '64',
                          style: TextStyle(
                            color: Shared.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Character type toggles
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Shared.surface,
                  borderRadius: BorderRadius.circular(Shared.cardBorderRadius),
                  border: Border.all(color: Shared.border),
                ),
                child: Column(
                  children: [
                    _toggleTile(
                      label: 'Lowercase',
                      sample: 'a b c d e f',
                      value: _useLowercase,
                      onChanged: (v) {
                        setState(() => _useLowercase = v);
                        _generate();
                      },
                    ),
                    _divider(),
                    _toggleTile(
                      label: 'Uppercase',
                      sample: 'A B C D E F',
                      value: _useUppercase,
                      onChanged: (v) {
                        setState(() => _useUppercase = v);
                        _generate();
                      },
                    ),
                    _divider(),
                    _toggleTile(
                      label: 'Numbers',
                      sample: '0 1 2 3 4 5',
                      value: _useNumbers,
                      onChanged: (v) {
                        setState(() => _useNumbers = v);
                        _generate();
                      },
                    ),
                    _divider(),
                    _toggleTile(
                      label: 'Symbols',
                      sample: '! @ # \$ % ^',
                      value: _useSymbols,
                      onChanged: (v) {
                        setState(() => _useSymbols = v);
                        _generate();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Shared.gold,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Shared.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleTile({
    required String label,
    required String sample,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Shared.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sample,
                  style: const TextStyle(
                    color: Shared.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Shared.gold,
            inactiveTrackColor: Shared.border,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      color: Shared.border,
      height: 1,
      indent: 12,
      endIndent: 12,
    );
  }
}
