class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  Future<void> initialize() async {}

  Future<void> scheduleDailyMedication({
    required String planId,
    required String memberName,
    required String medicationName,
    required String dose,
    required int hour,
    required int minute,
  }) async {}
}
