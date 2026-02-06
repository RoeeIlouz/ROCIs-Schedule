import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CourseListScreen extends StatelessWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('my_courses'))),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.translate('no_courses')),
                  TextButton(
                    onPressed: () => context.push('/courses/add'),
                    child: Text(l10n.translate('add_first_course')),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.courses.length,
            itemBuilder: (context, index) {
              final course = provider.courses[index];
              return Dismissible(
                key: Key(course.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await _showDeleteConfirmation(
                    context,
                    l10n,
                    course.name,
                  );
                },
                onDismissed: (direction) {
                  provider.deleteCourse(course.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.translate('course_deleted'))),
                  );
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: course.color),
                    title: Text(
                      course.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${course.code} • ${course.instructor}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${course.credits} ${l10n.translate('credits_label')}',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 20,
                          ),
                          onPressed: () async {
                            final confirmed = await _showDeleteConfirmation(
                              context,
                              l10n,
                              course.name,
                            );
                            if (confirmed == true) {
                              provider.deleteCourse(course.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.translate('course_deleted'),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      final events = context
                          .read<CourseProvider>()
                          .getEventsByCourse(course.id);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (sheetContext) {
                          final theme = Theme.of(sheetContext);
                          return SafeArea(
                            child: FractionallySizedBox(
                              heightFactor: 0.8,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            course.name,
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.red.shade400,
                                          ),
                                          onPressed: () async {
                                            Navigator.of(sheetContext).pop();
                                            final confirmed =
                                                await _showDeleteConfirmation(
                                                  context,
                                                  l10n,
                                                  course.name,
                                                );
                                            if (confirmed == true) {
                                              provider.deleteCourse(course.id);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      l10n.translate(
                                                        'course_deleted',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${course.code} • ${course.instructor}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${course.credits} ${l10n.translate('credits_label')}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    Text(
                                      l10n.translate('events'),
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: events.isEmpty
                                          ? Center(
                                              child: Text(
                                                l10n.translate('no_events'),
                                              ),
                                            )
                                          : ListView.separated(
                                              itemCount: events.length,
                                              separatorBuilder:
                                                  (context, index) =>
                                                      const Divider(height: 1),
                                              itemBuilder: (context, index) {
                                                final event = events[index];
                                                final timeText =
                                                    _formatEventTime(
                                                      context,
                                                      event,
                                                    );
                                                final locationText =
                                                    event.location.isNotEmpty
                                                    ? ' • ${event.location}'
                                                    : '';
                                                return ListTile(
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(event.title),
                                                  subtitle: Text(
                                                    '$timeText$locationText',
                                                  ),
                                                  trailing: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons.delete_outline,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                          size: 18,
                                                        ),
                                                        onPressed: () async {
                                                          final eventProvider =
                                                              context
                                                                  .read<
                                                                    CourseProvider
                                                                  >();
                                                          final confirmed =
                                                              await _showDeleteEventConfirmation(
                                                                context,
                                                                l10n,
                                                                event.title,
                                                              );
                                                          if (confirmed ==
                                                              true) {
                                                            eventProvider
                                                                .deleteEvent(
                                                                  event.id,
                                                                );
                                                            if (context
                                                                .mounted) {
                                                              Navigator.of(
                                                                sheetContext,
                                                              ).pop();
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    l10n.translate(
                                                                      'event_deleted',
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        },
                                                      ),
                                                      Icon(
                                                        _getEventIcon(
                                                          event.type,
                                                        ),
                                                        color: course.color,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/courses/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    AppLocalizations l10n,
    String courseName,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_course')),
        content: Text(
          l10n
              .translate('delete_course_confirm')
              .replaceAll('{name}', courseName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteEventConfirmation(
    BuildContext context,
    AppLocalizations l10n,
    String eventTitle,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_event')),
        content: Text(
          l10n
              .translate('delete_event_confirm')
              .replaceAll('{title}', eventTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );
  }

  String _formatEventTime(BuildContext context, ScheduleEvent event) {
    final themeProvider = context.read<ThemeProvider>();
    final use24Hour = themeProvider.use24HourFormat;

    String start;
    String end;

    if (use24Hour) {
      start = DateFormat.Hm().format(event.startTime);
      end = DateFormat.Hm().format(event.endTime);
    } else {
      start = DateFormat.jm().format(event.startTime);
      end = DateFormat.jm().format(event.endTime);
    }

    if (event.recurring && event.daysOfWeek.isNotEmpty) {
      final l10n = AppLocalizations.of(context)!;
      final weekdayNames = l10n.locale.languageCode == 'he'
          ? ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שבת']
          : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final days = event.daysOfWeek
          .map((day) => weekdayNames[day % 7])
          .join(', ');
      return '$days • $start - $end';
    }
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(event.startTime);
    return '$date • $start - $end';
  }

  IconData _getEventIcon(EventType type) {
    switch (type) {
      case EventType.classType:
        return Icons.class_outlined;
      case EventType.exam:
        return Icons.assignment_outlined;
      case EventType.lab:
        return Icons.science_outlined;
      case EventType.study:
        return Icons.menu_book_outlined;
      case EventType.other:
        return Icons.event_outlined;
    }
  }
}
