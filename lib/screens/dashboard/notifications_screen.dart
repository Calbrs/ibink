import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// FIX: Notifications screen - kwa sasa inatumia DUMMY DATA pekee.
/// Backend haijaunganishwa bado (hakuna endpoint ya /api/seller/notifications).
/// Badilisha _dummyNotifications na muunganiko halisi wa ApiClient pale
/// endpoint itakapokuwa tayari (mfano GET /api/seller/notifications).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _NotifType { order, stock, payment, system }

class _NotificationItem {
  final _NotifType type;
  final String title;
  final String message;
  final DateTime time;
  final bool isRead;

  const _NotificationItem({
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    this.isRead = false,
  });
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // ============== DUMMY DATA - badilisha na data halisi ya API ==============
  late List<_NotificationItem> _notifications = [
    _NotificationItem(
      type: _NotifType.order,
      title: 'Oda Mpya Imepokelewa',
      message: 'Umepata oda mpya ya #1042 kutoka kwa Amina Hassan - TZS 24,500.',
      time: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    _NotificationItem(
      type: _NotifType.stock,
      title: 'Stock Inaisha',
      message: '"Wireless Earbuds Pro" zimebaki vipande 3 tu. Ongeza stock haraka.',
      time: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    _NotificationItem(
      type: _NotifType.payment,
      title: 'Malipo Yamethibitishwa',
      message: 'Malipo ya oda #1039 (TZS 15,200) yamethibitishwa na yatalipwa wiki hii.',
      time: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
    ),
    _NotificationItem(
      type: _NotifType.order,
      title: 'Oda Imekamilika',
      message: 'Oda #1035 imethibitishwa kupokelewa na mteja. Asante kwa huduma nzuri!',
      time: DateTime.now().subtract(const Duration(hours: 9)),
      isRead: true,
    ),
    _NotificationItem(
      type: _NotifType.system,
      title: 'Sasisho la Duka',
      message: 'Wasifu wa duka lako umepitiwa na kuidhinishwa na timu yetu.',
      time: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
    ),
    _NotificationItem(
      type: _NotifType.stock,
      title: 'Bidhaa Imeisha',
      message: '"Phone Case Premium" haipo tena stock. Wateja hawawezi kuiagiza.',
      time: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
    ),
  ];
  // ============================================================================

  IconData _iconFor(_NotifType type) {
    switch (type) {
      case _NotifType.order:
        return Icons.receipt_long_outlined;
      case _NotifType.stock:
        return Icons.inventory_2_outlined;
      case _NotifType.payment:
        return Icons.account_balance_wallet_outlined;
      case _NotifType.system:
        return Icons.info_outline_rounded;
    }
  }

  Color _colorFor(_NotifType type) {
    switch (type) {
      case _NotifType.order:
        return AppColors.green;
      case _NotifType.stock:
        return AppColors.amber;
      case _NotifType.payment:
        return AppColors.greenDeep;
      case _NotifType.system:
        return AppColors.inkSoft;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Sasa hivi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika zilizopita';
    if (diff.inHours < 24) return '${diff.inHours} saa zilizopita';
    if (diff.inDays == 1) return 'Jana';
    return '${diff.inDays} siku zilizopita';
  }

  void _markAllRead() {
    setState(() {
      _notifications = _notifications
          .map((n) => _NotificationItem(
                type: n.type,
                title: n.title,
                message: n.message,
                time: n.time,
                isRead: true,
              ))
          .toList();
    });
  }

  void _markAsRead(int index) {
    if (_notifications[index].isRead) return;
    setState(() {
      final n = _notifications[index];
      _notifications[index] = _NotificationItem(
        type: n.type,
        title: n.title,
        message: n.message,
        time: n.time,
        isRead: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        ),
        title: const Text(
          'Arifa',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Weka Zote Kama Zimesomwa',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _notifications.isEmpty
          ? _EmptyNotifications()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return _NotificationCard(
                  icon: _iconFor(n.type),
                  color: _colorFor(n.type),
                  title: n.title,
                  message: n.message,
                  timeLabel: _timeAgo(n.time),
                  isRead: n.isRead,
                  onTap: () => _markAsRead(index),
                );
              },
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String timeLabel;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isRead ? AppColors.panel : AppColors.greenSoft.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6, top: 3),
                            decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      timeLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.inkFaint, fontWeight: FontWeight.w600),
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
}

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, color: AppColors.green, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hakuna arifa kwa sasa',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}