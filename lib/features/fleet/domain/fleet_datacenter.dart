import '../../cluster_overview/domain/datacenter_health.dart';
import '../../connection_profiles/domain/connection_profile.dart';

enum FleetDatacenterState { healthy, warning, critical, unavailable }

class FleetDatacenter {
  const FleetDatacenter({
    required this.profile,
    required this.state,
    this.health,
    this.message,
    this.updatedAt,
  });

  final ConnectionProfile profile;
  final FleetDatacenterState state;
  final DatacenterHealth? health;
  final String? message;
  final DateTime? updatedAt;
}
