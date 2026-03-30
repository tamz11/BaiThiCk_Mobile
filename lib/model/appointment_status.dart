class AppointmentStatus {
  AppointmentStatus._();

  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const Set<String> allowed = {pending, confirmed, completed, cancelled};

  static String normalize(String? value) {
    final status = (value ?? '').trim().toLowerCase();
    if (allowed.contains(status)) return status;
    return pending;
  }

  static bool canTransition({required String from, required String to}) {
    final source = normalize(from);
    final target = normalize(to);

    if (source == target) return true;

    switch (source) {
      case pending:
        return target == confirmed || target == cancelled;
      case confirmed:
        return target == pending || target == completed || target == cancelled;
      case completed:
        return false;
      case cancelled:
        return false;
      default:
        return false;
    }
  }

  static String label(String status) {
    final normalized = normalize(status);
    switch (normalized) {
      case confirmed:
        return 'Confirmed';
      case completed:
        return 'Completed';
      case cancelled:
        return 'Cancelled';
      case pending:
      default:
        return 'Pending';
    }
  }
}
