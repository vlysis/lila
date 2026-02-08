import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/reminder_service.dart';
import '../theme/lila_theme.dart';

class ReminderBottomSheet extends StatefulWidget {
  final VoidCallback onSaved;
  final ReminderService? reminderService;

  const ReminderBottomSheet({
    super.key,
    required this.onSaved,
    this.reminderService,
  });

  @override
  State<ReminderBottomSheet> createState() => _ReminderBottomSheetState();
}

class _ReminderBottomSheetState extends State<ReminderBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  late DateTime _selectedDay;
  late TimeOfDay _selectedTime;
  int _selectedOffset = 0;
  bool _saving = false;
  String? _errorText;

  ReminderService get _service =>
      widget.reminderService ?? ReminderService.instance;

  static const List<({String label, int minutes})> _offsetOptions = [
    (label: 'At time', minutes: 0),
    (label: '10 min before', minutes: 10),
    (label: '30 min before', minutes: 30),
    (label: '1 hour before', minutes: 60),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    final nextHour = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      0,
    ).add(const Duration(hours: 1));
    _selectedDay = DateTime(nextHour.year, nextHour.month, nextHour.day);
    _selectedTime = TimeOfDay(hour: nextHour.hour, minute: nextHour.minute);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<DateTime> _dayOptions() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (index) => today.add(Duration(days: index)));
  }

  DateTime _selectedReminderDateTime() {
    return DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() {
      _selectedTime = picked;
    });
  }

  Future<void> _saveReminder() async {
    if (_saving) return;

    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Add a reminder note first.');
      return;
    }

    final remindAt = _selectedReminderDateTime();
    final alertAt = remindAt.subtract(Duration(minutes: _selectedOffset));
    final now = DateTime.now();
    if (!remindAt.isAfter(now)) {
      setState(() => _errorText = 'Choose a future reminder time.');
      return;
    }
    if (!alertAt.isAfter(now)) {
      setState(() {
        _errorText =
            'That alarm would fire in the past. Pick a later time or smaller offset.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final result = await _service.createReminder(
      text: text,
      remindAt: remindAt,
      alertOffsetMinutes: _selectedOffset,
    );

    if (!mounted) return;

    String? feedbackMessage;
    if (!result.notificationPermissionGranted) {
      feedbackMessage =
          'Notification permission is off. Enable it for reminders.';
    } else if (!result.exactAlarmAllowed) {
      feedbackMessage =
          'Exact alarm permission is off. Reminders may be delayed.';
    } else if (!result.alarmScheduled) {
      feedbackMessage = 'Saved reminder, but alarm scheduling failed.';
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    widget.onSaved();
    Navigator.of(context).pop();
    if (feedbackMessage != null) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(feedbackMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radii = context.lilaRadii;
    final onSurface = colorScheme.onSurface;
    final timeLabel = _selectedTime.format(context);

    return AnimatedPadding(
      key: const ValueKey('reminder_sheet_inset_padding'),
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: theme.bottomSheetTheme.backgroundColor ?? colorScheme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radii.large),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(radii.small),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Set reminder',
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.86),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('reminder_text_input'),
                controller: _textController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Remember to buy vegetables',
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(radii.medium),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('save_reminder_button'),
                  onPressed: _saving ? null : _saveReminder,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(_saving ? 'Saving...' : 'Set Reminder'),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorText!,
                  style: TextStyle(color: colorScheme.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Day',
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _dayOptions().map((day) {
                  final isSelected = day == _selectedDay;
                  final dayLabel = DateFormat('EEE').format(day);
                  final numberLabel = DateFormat('d').format(day);
                  return ChoiceChip(
                    key: ValueKey(
                      'reminder_day_${DateFormat('yyyy-MM-dd').format(day)}',
                    ),
                    selected: isSelected,
                    label: Text('$dayLabel $numberLabel'),
                    onSelected: (_) {
                      setState(() => _selectedDay = day);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(
                'Time',
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('reminder_time_button'),
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_outlined, size: 18),
                label: Text(timeLabel),
              ),
              const SizedBox(height: 20),
              Text(
                'Alarm',
                style: TextStyle(
                  color: onSurface.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _offsetOptions.map((option) {
                  final selected = _selectedOffset == option.minutes;
                  return ChoiceChip(
                    key: ValueKey('reminder_offset_${option.minutes}'),
                    selected: selected,
                    label: Text(option.label),
                    onSelected: (_) {
                      setState(() => _selectedOffset = option.minutes);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
