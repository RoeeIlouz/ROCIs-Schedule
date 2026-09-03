import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

class CrossAppBridgeService {
  static const String _tasksScheme = 'rocistasks';
  static const String _tasksPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.rocisapps.tasks';
  static const String _tasksWebUrl = 'https://tasks.rocisapps.com';

  static Future<bool> isRocisTasksInstalled() async {
    try {
      final uri = Uri.parse('$_tasksScheme://open');
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openRocisTasks() async {
    try {
      final appUri = Uri.parse('$_tasksScheme://open');
      if (await canLaunchUrl(appUri)) {
        return await launchUrl(appUri, mode: LaunchMode.externalApplication);
      }
      // Fallback to web / Play Store
      final fallbackUri = Uri.parse(kIsWeb ? _tasksWebUrl : _tasksPlayStoreUrl);
      return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('CrossAppBridgeService: Failed to open ROCIs Tasks: $e');
      return false;
    }
  }

  static Future<bool> sendAssignmentToTasks({
    required Assignment assignment,
    Course? course,
  }) async {
    try {
      final queryParams = <String, String>{
        'title': assignment.title,
        'dueDate': assignment.dueDate.toIso8601String(),
        'priority': assignment.priority.name,
        if (assignment.description.isNotEmpty) 'notes': assignment.description,
        if (course != null) 'category': course.name,
      };

      final uri = Uri(
        scheme: _tasksScheme,
        host: 'add_task',
        queryParameters: queryParams,
      );

      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // App not installed, open store / web
        final fallbackUri = Uri.parse(_tasksPlayStoreUrl);
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('CrossAppBridgeService: Failed to export assignment: $e');
      return false;
    }
  }
}
