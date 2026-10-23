import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_logger.dart';
import '../../core/theme.dart';
import '../../widgets/notification_modals.dart';

/// In-app log viewer.
///
/// Shows what `flutter.log` contains, lets you filter by level, copy the whole
/// thing to the clipboard, or share the file out to WhatsApp/email. This exists
/// because the log file lives in an app sandbox the user cannot reach on a
/// phone — without this screen there is no way to get the log off the device.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogLevel _minLevel = LogLevel.debug;
  bool _onlyErrors = false;
  String _query = '';
  int _sizeBytes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await AppLogger.instance.flush();
    final size = await AppLogger.instance.sizeBytes();
    if (!mounted) return;
    setState(() => _sizeBytes = size);
  }

  List<LogEntry> get _filtered {
    final entries = AppLogger.instance.entries.reversed.toList();
    return entries.where((e) {
      if (_onlyErrors && e.level != LogLevel.error) return false;
      if (e.level.severity < _minLevel.severity) return false;
      if (_query.trim().isNotEmpty) {
        final q = _query.toLowerCase();
        if (!e.message.toLowerCase().contains(q) &&
            !e.tag.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String get _renderedText => _filtered.map((e) => e.formatted).join('\n');

  Future<void> _copy() async {
    final text = _renderedText;
    if (text.isEmpty) {
      NotificationService.showErrorBanner(context, message: 'Hakuna log ya kunakili.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    NotificationService.showSuccessBanner(
      context,
      message: 'Log imenakiliwa (${text.length} herufi).',
    );
  }

  Future<void> _share() async {
    AppLogger.instance.info('Logs', 'User requested log export.');
    final path = await AppLogger.instance.exportCopy();
    if (!mounted) return;

    if (path == null) {
      await _copy();
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: 'Onbaio Seller logs',
          text: 'Attached is the Onbaio Seller app log.',
        ),
      );
      AppLogger.instance.info('Logs', 'Log shared from $path.');
    } catch (e, st) {
      AppLogger.instance.error('Logs', 'Share failed', e, st);
      if (!mounted) return;
      NotificationService.showErrorBanner(
        context,
        message: 'Imeshindwa kutuma log. Tumia nakala badala yake.',
      );
      await _copy();
    }
  }

  Future<void> _clear() async {
    final confirmed = await NotificationService.showConfirmation(
      context,
      title: 'Futa log?',
      message: 'Log zote zitafutwa na hazitapatikana tena.',
      confirmText: 'Futa',
      cancelText: 'Ghairi',
      isDestructive: true,
    );
    if (!confirmed) return;
    await AppLogger.instance.clear();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    final location = AppLogger.instance.fileLocation;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Log za Programu',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            onPressed: _clear,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMetaCard(location),
          _buildFilters(),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: entries.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) => _LogTile(entry: entries[index]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildActions(entries.length),
    );
  }

  Widget _buildMetaCard(String? location) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 16, color: AppColors.green),
              const SizedBox(width: 8),
              Text(
                AppLogger.instance.isFileLoggingAvailable
                    ? '${(_sizeBytes / 1024).toStringAsFixed(1)} KB kwenye diski'
                    : 'Haiwezi kuhifadhi kwenye diski (web)',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            location ?? 'Inaonyesha kumbukumbu tu',
            style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Tafuta kwenye log…',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.inkSoft),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: LogLevel.values.map((level) {
                      final selected = !_onlyErrors && _minLevel == level;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _Chip(
                          label: level.label,
                          color: _colorFor(level),
                          selected: selected,
                          onTap: () => setState(() {
                            _onlyErrors = false;
                            _minLevel = level;
                          }),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'ERRORS',
                color: AppColors.danger,
                selected: _onlyErrors,
                onTap: () => setState(() {
                  _onlyErrors = !_onlyErrors;
                  if (_onlyErrors) _minLevel = LogLevel.debug;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActions(int count) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                label: Text('Nakili ($count)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.green),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Tuma'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded, size: 44, color: AppColors.line),
            const SizedBox(height: 12),
            Text(
              _query.isEmpty ? 'Hakuna log' : 'Hakuna log inayolingana',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Log zinaonekana hapa pale unapotumia programu.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  static Color _colorFor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return AppColors.inkSoft;
      case LogLevel.info:
        return AppColors.green;
      case LogLevel.warn:
        return const Color(0xFFF59E0B);
      case LogLevel.error:
        return AppColors.danger;
    }
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? color : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry entry;

  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _LogsScreenState._colorFor(entry.level);
    final time = entry.time.toIso8601String().replaceFirst('T', ' ').split('.').first;

    // A left colour stripe is a separate child rather than a Border side, because
    // Flutter throws "borderRadius can only be given on borders with uniform
    // colors" if you combine borderRadius with a per-side border colour.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.inkSoft,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.level.label,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.tag,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      entry.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.ink,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}