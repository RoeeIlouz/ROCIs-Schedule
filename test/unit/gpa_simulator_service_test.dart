import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/courses/services/gpa_simulator_service.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

void main() {
  group('GpaSimulatorService Tests', () {
    test('gradeToGpa maps percentage ranges to standard 4.0 scale accurately', () {
      expect(GpaSimulatorService.gradeToGpa(95), 4.0);
      expect(GpaSimulatorService.gradeToGpa(91), 3.7);
      expect(GpaSimulatorService.gradeToGpa(88), 3.3);
      expect(GpaSimulatorService.gradeToGpa(84), 3.0);
      expect(GpaSimulatorService.gradeToGpa(81), 2.7);
      expect(GpaSimulatorService.gradeToGpa(78), 2.3);
      expect(GpaSimulatorService.gradeToGpa(74), 2.0);
      expect(GpaSimulatorService.gradeToGpa(71), 1.7);
      expect(GpaSimulatorService.gradeToGpa(65), 1.0);
      expect(GpaSimulatorService.gradeToGpa(50), 0.0);
    });

    test('calculateTargetRequirement calculates goal-seeking required score accurately', () {
      final courses = [
        Course(
          id: 'c1',
          name: 'Calculus I',
          code: 'MATH101',
          instructor: 'Dr. Smith',
          color: const Color(0xFF4F46E5),
          credits: 4.0,
          grade: 80.0,
        ),
        Course(
          id: 'c2',
          name: 'Physics I',
          code: 'PHYS101',
          instructor: 'Dr. Brown',
          color: const Color(0xFF10B981),
          credits: 4.0,
          grade: 90.0,
        ),
        Course(
          id: 'c3',
          name: 'Computer Architecture',
          code: 'CS201',
          instructor: 'Dr. Turing',
          color: const Color(0xFFF59E0B),
          credits: 4.0,
          grade: null, // pending
        ),
      ];

      // Graded: 4*80 + 4*90 = 680 points across 8 credits (current avg = 85.0).
      // Total credits with c3 = 12.
      // Target average: 88.0 => required total points = 88 * 12 = 1056.
      // Required points for c3 = 1056 - 680 = 376 => required grade = 376 / 4 = 94.0.
      final result = GpaSimulatorService.calculateTargetRequirement(
        courses: courses,
        targetAverage: 88.0,
      );

      expect(result.gradedCredits, 8.0);
      expect(result.pendingCredits, 4.0);
      expect(result.currentAverage, 85.0);
      expect(result.requiredRemainingAverage, closeTo(94.0, 0.01));
      expect(result.feasibility, GpaFeasibility.challenging);
      expect(result.isAchievable, isTrue);
    });

    test('calculateTargetRequirement identifies unachievable target scores', () {
      final courses = [
        Course(
          id: 'c1',
          name: 'Math',
          code: 'M1',
          instructor: '',
          color: const Color(0xFF4F46E5),
          credits: 10.0,
          grade: 70.0,
        ),
        Course(
          id: 'c2',
          name: 'Elective',
          code: 'E1',
          instructor: '',
          color: const Color(0xFF10B981),
          credits: 2.0,
          grade: null,
        ),
      ];
      // Graded: 700 points, 10 credits. Total = 12 credits.
      // Target = 90.0 => 90 * 12 = 1080 points.
      // Required for c2 = (1080 - 700) / 2 = 190.0% => unachievable!
      final result = GpaSimulatorService.calculateTargetRequirement(
        courses: courses,
        targetAverage: 90.0,
      );

      expect(result.requiredRemainingAverage, closeTo(190.0, 0.01));
      expect(result.feasibility, GpaFeasibility.unachievable);
      expect(result.isAchievable, isFalse);
    });

    test('simulateHypotheticalGrades projects what-if GPA correctly', () {
      final courses = [
        Course(
          id: 'c1',
          name: 'Course 1',
          code: 'C1',
          instructor: '',
          color: const Color(0xFF4F46E5),
          credits: 3.0,
          grade: 80.0,
        ),
        Course(
          id: 'c2',
          name: 'Course 2',
          code: 'C2',
          instructor: '',
          color: const Color(0xFF10B981),
          credits: 3.0,
          grade: null,
        ),
      ];

      final hypothetical = {'c2': 100.0};
      final sim = GpaSimulatorService.simulateHypotheticalGrades(
        courses: courses,
        hypotheticalGrades: hypothetical,
      );

      // (3*80 + 3*100) / 6 = 90.0% => GPA 3.7
      expect(sim.average, 90.0);
      expect(sim.gpa, 3.7);
      expect(sim.totalCredits, 6.0);
    });
  });
}
