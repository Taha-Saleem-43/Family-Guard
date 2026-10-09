class PushDeliverySummary {
  final int accepted, received, opened, pending, failed;
  const PushDeliverySummary({
    this.accepted = 0,
    this.received = 0,
    this.opened = 0,
    this.pending = 0,
    this.failed = 0,
  });

  factory PushDeliverySummary.fromJobs(Iterable<Map<String, dynamic>> jobs) {
    var accepted = 0, received = 0, opened = 0, pending = 0, failed = 0;
    for (final job in jobs) {
      if (job['status'] == 'sent') accepted++;
      if (job['receivedAt'] != null) received++;
      if (job['openedAt'] != null) opened++;
      if (['pending', 'processing'].contains(job['status'])) pending++;
      if (['failed', 'expired', 'cancelled'].contains(job['status'])) failed++;
    }
    return PushDeliverySummary(
      accepted: accepted,
      received: received,
      opened: opened,
      pending: pending,
      failed: failed,
    );
  }
}
