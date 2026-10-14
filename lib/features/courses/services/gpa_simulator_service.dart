import 'package:rocis_schedule/shared/models/schedule_models.dart';

enum GpaFeasibility {
  secured,
  achievable,
  challenging,
  unachievable,
  noPendingCredits,
}

class GpaSimulationResult {
  final double targetAverage;
  final double? currentAverage;
  final double? currentGpa;
  final double gradedCredits;
  final double pendingCredits;
  final double totalCredits;
  final double? requiredRemainingAverage;
  final GpaFeasibility feasibility;

  const GpaSimulationResult({
    required this.targetAverage,
    required this.currentAverage,
    required this.currentGpa,
    required this.gradedCredits,
    required this.pendingCredits,
    required this.totalCredits,
    required this.requiredRemainingAverage,
    required this.feasibility,
  });

  bool get isAchievable =>
      feasibility == GpaFeasibility.secured ||
      feasibility == GpaFeasibility.achievable ||
      feasibility == GpaFeasibility.challenging;
}

class GpaSimulatorService {
  /// Converts a percentage grade (0-100) to standard 4.0 scale GPA.
  static double gradeToGpa(double grade) {
    if (grade <= 4.0) return grade;
    if (grade >= 93) return 4.0;
    if (grade >= 90) return 3.7;
    if (grade >= 87) return 3.3;
    if (grade >= 83) return 3.0;
    if (grade >= 80) return 2.7;
    if (grade >= 77) return 2.3;
    if (grade >= 73) return 2.0;
    if (grade >= 70) return 1.7;
    if (grade >= 60) return 1.0;
    return 0.0;
  }

  /// Calculates the required average across pending courses to achieve [targetAverage].
  static GpaSimulationResult calculateTargetRequirement({
    required List<Course> courses,
    required double targetAverage,
  }) {
    final graded = courses.where((c) => c.grade != null).toList();
    final pending = courses.where((c) => c.grade == null).toList();

    final gradedCredits = graded.fold<double>(0.0, (sum, c) => sum + c.credits);
    final pendingCredits = pending.fold<double>(0.0, (sum, c) => sum + c.credits);
    final totalCredits = gradedCredits + pendingCredits;

    final gradedPoints = graded.fold<double>(
      0.0,
      (sum, c) => sum + (c.grade! * c.credits),
    );

    final currentAverage = gradedCredits > 0 ? (gradedPoints / gradedCredits) : null;
    final currentGpa = currentAverage != null ? gradeToGpa(currentAverage) : null;

    if (pendingCredits <= 0) {
      return GpaSimulationResult(
        targetAverage: targetAverage,
        currentAverage: currentAverage,
        currentGpa: currentGpa,
        gradedCredits: gradedCredits,
        pendingCredits: 0.0,
        totalCredits: totalCredits,
        requiredRemainingAverage: null,
        feasibility: GpaFeasibility.noPendingCredits,
      );
    }

    // Formula: (gradedPoints + (requiredAvg * pendingCredits)) / totalCredits = targetAverage
    // => requiredAvg = (targetAverage * totalCredits - gradedPoints) / pendingCredits
    final requiredAvg = ((targetAverage * totalCredits) - gradedPoints) / pendingCredits;

    final GpaFeasibility feasibility;
    if (requiredAvg <= 60.0) {
      feasibility = GpaFeasibility.secured;
    } else if (requiredAvg <= 89.9) {
      feasibility = GpaFeasibility.achievable;
    } else if (requiredAvg <= 100.0) {
      feasibility = GpaFeasibility.challenging;
    } else {
      feasibility = GpaFeasibility.unachievable;
    }

    return GpaSimulationResult(
      targetAverage: targetAverage,
      currentAverage: currentAverage,
      currentGpa: currentGpa,
      gradedCredits: gradedCredits,
      pendingCredits: pendingCredits,
      totalCredits: totalCredits,
      requiredRemainingAverage: requiredAvg,
      feasibility: feasibility,
    );
  }

  /// Calculates the simulated average and GPA when hypothetical grades are applied
  /// to pending courses.
  static ({double average, double gpa, double totalCredits}) simulateHypotheticalGrades({
    required List<Course> courses,
    required Map<String, double> hypotheticalGrades,
  }) {
    double totalPoints = 0.0;
    double totalCreds = 0.0;

    for (final c in courses) {
      final grade = c.grade ?? hypotheticalGrades[c.id];
      if (grade != null) {
        totalPoints += grade * c.credits;
        totalCreds += c.credits;
      }
    }

    if (totalCreds == 0) {
      return (average: 0.0, gpa: 0.0, totalCredits: 0.0);
    }

    final avg = totalPoints / totalCreds;
    return (
      average: avg,
      gpa: gradeToGpa(avg),
      totalCredits: totalCreds,
    );
  }
}
