import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../routes/app_routes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _newOrderAlerts = true;
  bool _lowStockAlerts = true;
  bool _emailUpdates = false;
  bool _scannerSound = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _scannerSound = prefs.getBool('scanner_sound') ?? false;
    });
  }

  Future<void> _updateScannerSound(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('scanner_sound', value);
    setState(() {
      _scannerSound = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Mipangilio')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SectionHeader('Arifa'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Oda mpya'),
                    subtitle: const Text('Pata arifa unapopokea oda mpya', style: TextStyle(fontSize: 12)),
                    value: _newOrderAlerts,
                    activeThumbColor: AppColors.green,
                    onChanged: (v) => setState(() => _newOrderAlerts = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Stock ndogo'),
                    subtitle: const Text('Pata arifa bidhaa zinapopungua', style: TextStyle(fontSize: 12)),
                    value: _lowStockAlerts,
                    activeThumbColor: AppColors.green,
                    onChanged: (v) => setState(() => _lowStockAlerts = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Taarifa za barua pepe'),
                    value: _emailUpdates,
                    activeThumbColor: AppColors.green,
                    onChanged: (v) => setState(() => _emailUpdates = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Scanner (POS)'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
              child: SwitchListTile(
                title: const Text('Sauti ya Scanner (Beep)'),
                subtitle: const Text('Washa sauti ya beep badala ya mtetemo tu (Vibrate)', style: TextStyle(fontSize: 12)),
                value: _scannerSound,
                activeThumbColor: AppColors.green,
                onChanged: _updateScannerSound,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Duka'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
              child: Column(
                children: [
                  _NavTile(title: 'Taarifa za malipo', onTap: () {}),
                  const Divider(height: 1),
                  _NavTile(title: 'Anwani ya kujifungua', onTap: () {}),
                  const Divider(height: 1),
                  _NavTile(title: 'Wafanyakazi wa duka', onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeader('Kuhusu'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
              child: Column(
                children: [
                  _NavTile(title: 'Vigezo vya Huduma', onTap: () {}),
                  const Divider(height: 1),
                  _NavTile(title: 'Sera ya Faragha', onTap: () {}),
                  const Divider(height: 1),
                  _NavTile(title: 'Kuhusu Onbaio', onTap: () {}),
                  const Divider(height: 1),
                  _NavTile(
                    title: 'Log za Programu',
                    subtitle: 'Angalia au tuma log za hitilafu',
                    onTap: () => context.push(AppRoutes.logs),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.inkSoft, letterSpacing: 0.4));
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _NavTile({required this.title, required this.onTap, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppColors.inkFaint),
      onTap: onTap,
    );
  }
}
